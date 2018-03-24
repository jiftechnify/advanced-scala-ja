## Validated

今のところ、我々は`Either`のフェイルファストなエラー処理という振る舞いについてはよく理解している。
さらに`Either`はモナドなので、`product`のセマンティクスは`flatMap`のものと同様であることも知っている。
実際、これら2つのメソッドの一貫性を壊すことなく、エラーを蓄積するようなセマンティクスを実装するモナド的データ型を設計するのは不可能である。

幸い、Cats は`Validated`と呼ばれる、`Semigroupal`のインスタンスだが`Monad`のインスタンス **ではない** データ型を提供している。
よって、その`product`の実装は、自由にエラーを蓄積することができる:

```tut:book:silent
import cats.Semigroupal
import cats.data.Validated
import cats.instances.list._ // for Monoid

type AllErrorsOr[A] = Validated[List[String], A]
```

```tut:book
Semigroupal[AllErrorsOr].product(
  Validated.invalid(List("Error 1")),
  Validated.invalid(List("Error 2"))
)
```

`Validated`は`Either`をうまく補完している。
この2つによって、フェイルファストとエラーの蓄積という、一般的なエラー処理手法の両方を手に入れることができる。


### Validated のインスタンスの生成

`Validated`は、`Validated.Valid`と`Validated.Invalid`の2つのサブ型を持ち、これらは大まかに`Right`と`Left`に対応する。
これらの型のインスタンスを生成する多くの方法が用意されている。
`apply`メソッドを利用して、これらを直接生成できる:

```tut:book
val v = Validated.Valid(123)
val i = Validated.Invalid(List("Badness"))
```

しかし、返り値の型を`Validated`に広げた`valid`と`invalid`というスマートコンストラクタを利用したほうがより簡単である:

```tut:book
val v = Validated.valid[List[String], Int](123)
val i = Validated.invalid[List[String], Int](List("Badness"))
```

3つ目の選択肢として、`cats.syntax.validated`から`valid`・`invalid`拡張メソッドをインポートすることができる:

```tut:book:silent
import cats.syntax.validated._ // for valid and invalid
```

```tut:book:silent
123.valid[List[String]]
List("Badness").invalid[Int]
```

4つ目の選択肢は、それぞれ[`cats.syntax.applicative`][cats.syntax.applicative]と[`cats.syntax.applicativeError`][cats.syntax.applicativeError]にある。`pure`・`raiseError`を使うというものだ:

```tut:book:silent
import cats.syntax.applicative._      // for pure
import cats.syntax.applicativeError._ // for raiseError

type ErrorsOr[A] = Validated[List[String], A]
```

```tut:book
123.pure[ErrorsOr]
List("Badness").raiseError[ErrorsOr, Int]
```

最後に、別の値から`Validated`のインスタンスを生成するヘルパーメソッドもある。
`Exception`、`Try`、`Either`、そして`Option`のインスタンスから`Validated`を生成できる:

```tut:book
Validated.catchOnly[NumberFormatException]("foo".toInt)

Validated.catchNonFatal(sys.error("Badness"))

Validated.fromTry(scala.util.Try("foo".toInt))

Validated.fromEither[String, Int](Left("Badness"))

Validated.fromOption[String, Int](None, "Badness")
```

### Validated のインスタンスの合成

ここまでに説明した、任意の`Semigroupal`のメソッドや構文を用いて、`Validated`のインスタンスを合成することができる。

これらのすべてを用いるには、`Semigroupal`のインスタンスがスコープ内になければならない。
`Either`の場合と同様に、エラーの型を固定して、正しい数の型パラメータを持つ`Semigroupal`のための型コンストラクタを作る必要がある:

```tut:book:silent
type AllErrorsOr[A] = Validated[String, A]
```

`Validated`は`Semigroup`を用いてエラーを蓄積するので、`Semigroupal`のインスタンスを召喚するには`Semigroup`のインスタンスがスコープの中になければならない。
呼び出し地点において、見える`Semigroup`がなければ、いらいらするほど役に立たないコンパイルエラーが発生する:

```tut:book:fail
Semigroupal[AllErrorsOr]
```

エラーの型に対する`Semigroup`をインポートすれば、すべてが思ったとおりに動く:

```tut:book:silent
import cats.instances.string._ // for Semigroup
```

```tut:book
Semigroupal[AllErrorsOr]
```

正しい`Semigroupal`を召喚するのに必要なすべての暗黙の値がスコープの中にある限り、エラーを蓄積するために apply 構文や他のすべての`Semigroupal`のメソッドを好きに利用できる:

```tut:book:silent
import cats.syntax.apply._ // for tupled
```

```tut:book
(
  "Error 1".invalid[Int],
  "Error 2".invalid[Int]
).tupled
```

ご覧の通り、`String`はエラーを蓄積するのには向かない型である。
代わりに、`List`や`Vector`を利用するのが一般的だ:

```tut:book:silent
import cats.instances.vector._ // for Semigroupal
```

```tut:book
(
  Vector(404).invalid[Int],
  Vector(500).invalid[Int]
).tupled
```

`cats.data`パッケージは、1つもエラー出さずに失敗することがないよう、[`NonEmptyList`][cats.data.NonEmptyList]と[`NonEmptyVector`][cats.data.NonEmptyVector]という型も提供している:

```tut:book:silent
import cats.data.NonEmptyVector
```

```tut:book
(
  NonEmptyVector.of("Error 1").invalid[Int],
  NonEmptyVector.of("Error 2").invalid[Int]
).tupled
```

### Validated のメソッド

`Validated`は、[`cats.syntax.either`][cats.syntax.either]にあるメソッドを含む、`Either`で利用できるメソッドによく似たメソッドの数々を持っている。
`map`、`leftMap`、そして`bimap`を用いて、正常(valid)側と異常(invalid)側の値を変換することができる:

```tut:book
123.valid.map(_ * 100)

"?".invalid.leftMap(_.toString)

123.valid[String].bimap(_ + "!", _ * 100)

"?".invalid[Int].bimap(_ + "!", _ * 100)
```

`Validated`はモナドではないので、`flatMap`を行うことはできない。
しかし、Cats は`andThen`と呼ばれる`flatMap`の代役を提供している。
`andThen`の型シグネチャは`flatMap`と同一であるが、モナドの法則に従うような実装ではないため、別の名前になっている:

```tut:book
32.valid.andThen { a =>
  10.valid.map { b =>
    a + b
  }
}
```

`flatMap`以上のことをしたければ、`toEither`と`toValidated`メソッドを利用して`Validated`と`Either`を相互に変換することができる。
`toValidated`は[`cats.syntax.either`]にあるということに注意してほしい:

```tut:book
import cats.syntax.either._ // for toValidated

"Badness".invalid[Int]
"Badness".invalid[Int].toEither
"Badness".invalid[Int].toEither.toValidated
```

`Either`と同じように、条件が成り立たないときに指定したエラーとともに失敗する`ensure`メソッドを利用できる:

```tut:book
// 123.valid[String].ensure("Negative!")(_ > 0)
```

最後に、`getOrElse`や`fold`を用いて、`Valid`と`Invalid`の両方の場に対して値を取り出すことができる:

```tut:book
"fail".invalid[Int].getOrElse(0)

"fail".invalid[Int].fold(_ + "!!!", _.toString)
```

### 演習: フォームの入力値検査

シンプルな HTML によるユーザ登録フォームを実装して、`Validated`の扱いに慣れていこう。
クライアントからのリクエストデータは`Map[String, String]`という形で受け取り、それを解析して`User`オブジェクトを生成する:

```tut:book:silent
case class User(name: String, age: Int)
```

目標は、入力されたデータを解析し、次のルールを守らせるようなコードを実装することだ:

 - 名前(name)と年齢(age)は必須である
 - 名前は、空欄であってはならない
 - 年齢は、妥当な非負整数でなければならない

すべてのルールを通過した場合は`User`を返すようにする。
どれかのルールが満たされていない場合はエラーメッセージの`List`を返すようにすること。

この例を実装するには、ルールを逐次的にも、並行的にも組み合わせる必要がある。
`Either`を用い、フェイルファストなセマンティクスで計算を逐次的に合成し、
`Validated`を用い、エラーを蓄積するセマンティクスで計算を並行に合成する。

まず逐次的な合成からはじめよう。
`"name"`と`"age"`の2つのフィールドを読み取る2つのメソッドを定義する:

- `readName`は`Map[String, String]`を引数にとり、`"name"`フィールドを取り出して入力規則に沿ってチェックし、結果として`Either[List[String], String]`を返す

- `readAge`は`Map[String, String]`を引数にとり、`"age"`フィールドを取り出して入力規則に沿ってチェックし、結果として`Either[List[String], Int]`を返す

これらのメソッドはより小さな構成要素から構築できる。
まず、フィールド名が与えられると`Map`からそのフィールドの値である`String`を取り出す、`getValue`メソッドを定義しよう。

<div class="solution">
`Either`と`Validated`を利用しようとしているので、まずいくつかのインポートからはじめる:

```tut:book:silent
import cats.data.Validated

type FormData = Map[String, String]
type FailFast[A] = Either[List[String], A]
type FailSlow[A] = Validated[List[String], A]
```

`getValue`ルールはフォームのデータから`String`を取り出す。
これを、入力を`Int`として解析して値をチェックするルールとともに逐次的に利用するので、`Either`を返すように定義する:

```tut:book:silent
def getValue(name: String)(data: FormData): FailFast[String] =
  data.get(name).
    toRight(List(s"$name field not specified"))
```

`getValue`のインスタンスは次のように生成・利用できる:

```tut:book
val getName = getValue("name") _

getName(Map("name" -> "Dade Murphy"))
```

フィールドが見つからなかった場合は、適切なフィールド名を含むエラーメッセージを返す:

```tut:book
getName(Map())
```
</div>

次に、`String`を受け取ってそれを`Int`として解析する`parseInt`メソッドを定義せよ。

<div class="solution">
ここでも`Either`を利用する。
`toInt`から送出される`NumberFormatException`を受け取るのに`Either.catchOnly`を利用し、それをエラーメッセージに変換するのに`leftMap`を利用する:

```tut:book:silent
import cats.syntax.either._ // for catchOnly

type = NumFmtExn = NumberFormatException

def parseInt(name: String)(data: String): FailFast[Int] =
  Either.catchOnly[NumFmtExn](data.toInt).
    leftMap(_ => List(s"$name must be an integer"))
```

この解答では、解析するフィールドの名前を指定するための追加の引数を受け取っていることに注意してほしい。
これはより良いエラーメッセージを生成するのに役立つが、なくても問題はない。

正しい入力を与えれば、`parseInt`はそれを`Int`に変換する:

```tut:book
parseInt("age")("11")
```

誤った入力を与えると、有用なエラーメッセージを得ることができる:

```tut:book
parseInt("age")("foo")
```
</div>

次に、入力値の検査を実装する。`String`をチェックする`nonBlank`と、`Int`をチェックする`nonNegative`を実装せよ。

<div class="solution">
これらの定義では、上と同じパターンを利用する:

```tut:book:silent
def nonBlank(name: String)(data: String): FailFast[String] =
  Right(data).
    ensure(List(s"$name cannot be blank"))(_.nonEmpty)

def nonNegative(name: String)(data: Int): FailFast[Int] =
  Right(data).
    ensure(List(s"$name must be non-negative))(_ >= 0)
```

これを利用する例をいくつか示す:

```tut:book
nonBlank("name")("Dade Murphy")
nonBlank("name")("")
nonNegative("age")(11)
nonNegative("age")(-1)
```
</div>

さて、`getValue`、`parseInt`、`nonBlank`、そして`nonNegative`を組み合わせて`readName`と`readAge`を実装しよう:

<div class="solution">
`flatMap`を利用して、これらのルールを逐次的に合成する:

```tut:book:silent
def readName(data: FormData): FailFast[String] =
  getValue("name")(data).
    flatMap(nonBlank("name"))

def readAge(data: FormData): FailFast[Int] =
  getValue("age")(data).
    flatMap(nonBlank("age")).
    flatMap(parseInt("age")).
    flatMap(nonNegative("age"))
```

この2つのルールは、これまで見てきたすべてのエラーを拾いだす:

```tut:book
readName(Map("name" -> "Dade Murphy"))
readName(Map("name" -> ""))
readName(Map())
readAge(Map("age" -> "11"))
readAge(Map("age" -> "-1"))
readAge(Map())
```
</div>

最後に、`Semigroupal`を利用して`readName`と`readAge`の結果を組み合わせ、`User`を生成するようにせよ。
エラーを蓄積するために、`Either`ではなく`Validated`を利用すること。

<div class="solution">
`Either`の代わりに`Validated`を利用し、apply 構文を使うことでこれを実現できる:

```tut:book:silent
import cats.instances.list._ // for Semigroupal
import cats.syntax.apply._   // for mapN

def readUser(data: FormData): FailSlow[User] =
  (
    readName(data).toValidated,
    readAge(data).toValidated
  ).mapN(User.apply)
```

```tut:book
readUser(Map("name" -> "Dave", "age" -> "37"))
readUser(Map("age" -> "-1"))
```

`Either`と`Validated`を相互に変換する必要があるのは腹立たしい。
`Either`と`Validated`のどちらをデフォルトで利用するかの選択は、文脈によって決まる。
アプリケーションのコードでは、エラーを蓄積するセマンティクスが適している領域とフェイルファストなセマンティクスが適している領域の両方が存在することが多い。
必要に応じて最適なデータ型を選び、特別な状況で必要に応じて他方へ切り替えるのである。
</div>
