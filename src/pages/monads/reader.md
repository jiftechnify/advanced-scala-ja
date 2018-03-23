## Reader モナド {#sec:monads:reader}

[`cats.data.Reader`][cats.data.Reader]は、ある入力値に依存するような連続した計算を構成することを可能にするモナドである。
`Reader`のインスタンスは1つの引数をとる関数を包み、それらを合成するのに便利なメソッドを提供する。

`Reader`の一般的な利用法の1つに依存性注入(dependency injection)がある。
それぞれが何らかの外部設定に依存するような多数の計算があるとき、`Reader`を用いてそれらを繋ぎ合わせ、設定値を引数として受け取って指定した順に実行するような、1つの大きな計算を生成することができる。

### Reader の生成と値の取り出し

`Reader.apply`コンストラクタを用いて、`A => B`型の関数から`Reader[A, B]`を生成できる:

```tut:book:silent
import cats.data.Reader
```

```tut:book
case class Cat(name: String, favoriteFood: String)

val catName: Reader[Cat, String] =
  Reader(cat => cat.name)
```

`Reader`の`run`メソッドを用いて関数を取り出し、いつものように`apply`でそれを呼び出すことができる:

```tut:book
catName.run(Cat("Garfield", "lasagne"))
```

今のところ非常に単純だが、生の関数ではなく`Reader`を使う利点とは何だろうか?

### Reader の合成

`Reader`の力は、`map`と`flatMap`メソッドに由来する。これらはそれぞれ違った種類の関数合成を表現する。
`Reader`の典型的な使い方は、同じ型の設定値を受け取るいくつかの`Reader`を生成し、`map`や`flatMap`によってそれらを組み合わせ、最後に `run`を呼び出して設定を注入する、というものだ。

`map`メソッドは単純に、計算の結果を与えた関数に通すようにすることで、`Reader`の中にある計算を拡張する:

```tut:book:silent
val greetKitty: Reader[Cat, String] =
  catName.map(name => s"Hello ${name}")
```

```tut:book
greetKitty.run(Cat("Heathcliff", "junk food"))
```

`flatMap`メソッドはもっと興味深い。
これによって、同じ型の入力に依存する reader たちを組み合わせることができる。
説明のために、上の例を、猫に餌を与えるように拡張しよう:

```tut:book:silent
val feedKitty: Reader[Cat, String] =
  Reader(cat => s"Have a nice bowl of ${cat.favoriteFood}")

val greetAndFeed: Reader[Cat, String] =
  for {
    greet <- greetKitty
    feed  <- feedKitty
  } yield s"$greet. $feed."
```

```tut:book
greetAndFeed(Cat("Garfield", "lasagne"))
greetAndFeed(Cat("Heathcliff", "junk food"))
```

### 演習: Reader をハックする

`Reader`の伝統的な利用法は、共通設定を引数として受け取るプログラムを組み立てることだ。
簡単なログインシステムの例を通してこれを理解していこう。
共通設定は2つのデータベースからなる。有効なユーザのリストと、そのパスワードのリストだ:

```tut:book
case class Db(
  usernames: Map[Int, String],
  passwords: Map[String, String]
)
```

`Db`を入力として消費する`Reader`に対する型エイリアスを作るところから始めよう。
これによって残りのコードはより短くなる。

<div class="soolution">
この型エイリアスは`Db`型を固定する一方で、結果の型は変更可能なままにする:

```tut:book:silent
type DbReader[A] = Reader[Db, A]
```
</div>

さて、`DbReader`に`Int`型のユーザIDからユーザ名を探すメソッドと、`String`型のユーザ名からそのユーザのパスワードを探すメソッドを作成しよう。
型シグネチャは次のようになるはずだ:

```tut:book:silent
def findUsername(userId: Int): DbReader[Option[String]] =
  ???

def checkPassword(
      username: String,
      password: String): DbReader[Boolean] =
  ???
```

<div class="solution">
覚えておこう: `Reader`の狙いは、共通設定の注入を最後まで残しておくことである。
これは、設定を引数として受け取る関数を組み上げ、与えられた具体的なユーザ情報に対してそれを適用することでチェックを行うということだ:

```tut:book:silent
def findUsername(userId: Int): DbReader[Option[String]] =
  Reader(db => db.usernames.get(userId))

def checkPassword(
      username: String,
      password: String): DbReader[Boolean] =
  Reader(db => db.passwords.get(username).contains(password))
```
</div>

最後に、与えられたユーザIDに対するパスワードをチェックする`checkLogin`メソッドを作ろう。
型シグネチャは次のようになるはずだ:

```tut:book:silent
def checkLogin(
      userId: Int,
      password: String): DbReader[Boolean] =
  ???
```

<div class="solution">
あなたが思ったとおり、ここで`findUsername`と`checkPassword`を繋ぐために`flatMap`を利用する。
ユーザ名が見つからなかったときに`Boolean`値を`DbReader[Boolean]`に持ち上げるために、`pure`を使う:

```tut:book:silent
import cats.syntax.applicative._ // for pure

def checkLogin(
      userId: Int,
      password: String): DbReader[Boolean] =
  for {
    username   <- findUsername(userId)
    passwordOk <- username.map { username =>
                    checkPassword(username, password)
                  }.getOrElse {
                    false.pure[DbReader]
                  }
  } yield passwordOk
```
</div>

`checkLogin`は次のように利用できるはずだ:

```tut:book:silent
val users = Map(
  1 -> "dade",
  2 -> "kate",
  3 -> "margo"
)

val passwords = Map(
  "dade"  -> "zerocool",
  "kate"  -> "acidburn",
  "margo" -> "secret"
)

val db = Db(users, passwords)
```

```tut:book
checkLogin(1, "zerocool").run(db)
checkLogin(4, "davinci").run(db)
```

### いつ Reader を使うべきか?

`Reader`は依存性注入を行うための道具を提供する。
`Reader`のインスタンスとしてプログラムの各ステップを書き、`map`や`flatMap`によってそれらを繋ぎ合わせ、入力として依存する値を受け取る関数を組み立てる。

Scala において依存性注入を実装する手法は多数存在する。複数の引数リストを持つメソッドのようなシンプルなテクニックから、暗黙のパラメータと型クラスを用いる方法、cake パターンや DI フレームワークのような複雑なテクニックまである。

`Reader`が最も有用な状況は、次のようなものである:

- 関数によって簡単に表現できるようなバッチプログラムを構築するとき

- 既知の引数や引数の集合を渡すのを先送りしなければならないとき

- プログラムの各部分を別々にテストしたいとき

`Reader`としてプログラムの各ステップを表現することで、それらを純粋な関数と同様に簡単にテストでき、その上`map`や`flatMap`というコンビネータを使えるようになる。

たくさんの依存性を持つ場合や、プログラムを純粋関数として表現するのが容易でない場合のような、より発展的な問題に対しては、他の依存性注入テクニックがより適していることが多い。

<div class="callout callout-warning">
  **クライスリ射(Kleisli Arrows)**

  コンソールの出力を見て、`Reader`が`Kleisli`と呼ばれる他の型を利用して実装されていることに気づいたかもしれない。
  **クライスリ射** は、返り値の型の型コンストラクタを抽象化した、`Reader`のより一般的な形である。
  [@sec:monad-transformers]章で再びクライスリに出会うことになるだろう。
</div>
