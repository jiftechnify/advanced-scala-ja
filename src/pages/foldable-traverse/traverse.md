## Traverse {#sec: traverse}

`foldLeft`と`foldRight`は柔軟性の高い反復処理メソッドだが、利用するには蓄積変数やコンビネータ関数を定義するのに多くの仕事をしなければならない。
`Traverse`型クラスは、より便利で規則的な反復処理のパターンを提供するために`Applicative`を利用する、より高レベルなツールである。

### Futureのトラバース

Scala 標準ライブラリの`Future.traverse`と`Future.sequence`メソッドを使って`Traverse`を説明する。
これらのメソッドは、`Future`に特化したトラバースパターンの実装である。
例えば、サーバのホスト名のリストと、ホストの稼働時間をポーリングするメソッドがあるとしよう:

```tut:book:silent
import scala.concurrent._
import scala.concurrent.duration._
import scala.concurrent.ExecutionContext.Implicits.global

val hostnames = List(
  "alpha.example.com",
  "beta.example.com",
  "gamma.example.com"
)

def getUptime(hostname: String): Future[Int] =
  Future(hostname.length * 60) // 単なる説明用の実装
```

ここで、すべてのホストをポーリングし、稼働時間をまとめたいとしよう。
単純に`hostname`を`map`するだけでは不十分だ。なぜなら、結果(`List[Future[Int]]`)は複数の`Future`を含んでいるからである。
ブロックできる何かを得るには、これを1つの`Future`にまとめる必要がある。
まず、畳み込みを利用して、この処理を手動で行ってみよう:

```tut:book:silent
val allUptimes: Future[List[Int]] =
  hostnames.foldLeft(Future(List.empty[Int])) {
    (accum, host) =>
      val uptime = getUptime(host)
      for {
        accum  <- accum
        uptime <- uptime
      } yield accum :+ uptime
  }
```

```tut:book
Await.result(allUptimes, 1.second)
```

直感的には、`hostname`の各要素を取り出し、その要素に`func`を適用し、そしてその結果をリストにまとめている。
これは単純に見えるが、要素ごとに`Future`を生成・合成する必要があるので、コードはかなり煩雑になっている。
このパターンに対する特製の機能である`Future.traverse`を利用すれば、これを大きく改善できる:

```tut:book:silent
val allUptimes: Future[List[Int]] =
  Future.traverse(hostnames)(getUptime)
```

```tut:book
Await.result(allUptimes, 1.second)
```

より明快で簡潔になった。これがどのように動作するのかを見ていこう。
`CanBuildFrom`や`ExecutionContext`のような本質と関係のないものを無視すると、標準ライブラリの`Future.traverse`の実装は次のようになっている:

```scala
def traverse[A, B](values: List[A])
    (func: A => Future[B]): Future[List[B]] =
  values.foldLeft(Future(List.empty[B])) { (accum, host) =>
    val item = func(host)
    for {
      accum <- accum
      item  <- item
    } yield accum :+ item
  }
```

これは本質的には、上の例におけるコードと同じである。
`Future.traverse`は畳み込みの痛みである、蓄積変数と合成を行う関数の定義を抽象化している。
`Future.traverse`は、次のことをするための、見通しがよく高レベルなインターフェイスを提供してくれる:

- `List[A]`から始め、
- `A => Future[B]`型の関数を与えると…
- 結果として`Future[List[B]]`が得られる

標準ライブラリはもうひとつのメソッド、`Future.sequence`を提供している。これは、既に`List[Future[B]]`があるときに`traverse`に恒等関数を渡さなくて済むようにするものである:

```scala
object Future {
  def sequence[B](futures: List[Future[B]]): Future[List[B]] =
    traverse(futures)(identity)

  // ...
}
```

この場合、直感的な理解はさらに簡単なものとなる:

- `List[Future[A]]`から…
- `Future[List[A]]`という結果を得る

`Future.traverse`と`Future.sequence`は非常に限られた問題を解決するものだ:
`Future`の列を反復処理してその結果を蓄積することを可能にする。
上の簡素化された例は`List`しか扱うことができないが、実際の`Future.traverse`や`Future.sequence`は任意の Scala コレクションを扱える。

Cats の`Traverse`型クラスはこれらのパターンを一般化し、`Future`、`Option`、`Validated`など、任意の`Applicative`型を扱えるようにしたものである。
次節では、`Traverse`に対し2ステップで近づいていく:
まず、`Applicative`について一般化し、次に順列の型について一般化する。
最終的に、順列や他のデータ型に関係する多くの操作を「自明な」ものにする、非常に価値のある道具を手に入れることになる。

### アプリカティブによるトラバース

目を細めて見ると、`traverse`を`Applicative`のメソッドで書き換えることができることが分かるだろう。
上の例における蓄積変数はこうなっていた:

```tut:book:silent
Future(List.empty[Int])
```

これは`Applicative.pure`と等価だ:

```tut:book:silent
import cats.Applicative
import cats.instances.future._   // for Applicative
import cats.syntax.applicative._ // for pure

List.empty[Int].pure[Future]
```

値を結合する関数は次のようなものだった:

```tut:book:silent
def oldCombine(
  accum : Future[List[Int]],
  host  : String
): Future[List[Int]] = {
  val uptime = getUptime(host)
  for {
    accum  <- accum
    uptime <- uptime
  } yield accum :+ uptime
}
```

これは`Semigroupal.combine`と等価だ:

```tut:book:silent
import cats.syntax.apply._ // for mapN

// Applicative を用いて蓄積変数とホスト名を結合する
def newCombine(accum: Future[List[Int]],
      host: String): Future[List[Int]] =
  (accum, getUptime(host)).mapN(_ :+ _)
```

`traverse`の定義をこれらのコード片で置き換えることで、任意の`Applicative`を扱えるように`traverse`を一般化できる:

```tut:book:silent
import scala.language.higherKinds

def listTraverse[F[_]: Applicative, A, B]
      (list: List[A])(func: A => F[B]): F[List[B]] =
  list.foldLeft(List.empty[B].pure[F]) { (accum, item) =>
    (accum, func(item)).mapN(_ :+ _))
  }

def listSequence[F[_]: Applicative, B]
      (list: List[F[B]]): F[List[B]] =
  listTraverse(list)(identity)
```

稼働時間を取得する例を、`listTraverse`を利用して再実装することができる:

```tut:book:silent
val totalUptime = listTraverse(hostnames)(getUptime)
```

```tut:book
Await.result(totalUptime, 1.second)
```

#### 演習: Vector のトラバース

次のコードの結果はどうなるだろうか?

```tut:book:silent
import cats.instances.vector._ // for Applicative

listSequence(List(Vector(1, 2), Vector(3, 4)))
```

<div class="solution">
引数の型は`List[Vector[Int]]`なので、これは`Vector`に対する`Applicative`を利用し、`Vector[List[Int]]`型の結果が得られる。

`Vector`はモナドなので、その semigroupal の`combine`関数は`flatMap`に基づいている。
結果として、`List(1, 2)`と`List(3, 4)`の値の可能な組み合わせである`List`うを要素に持つ`Vector`が得られる:

```tut:book
listSequence(List(Vector(1, 2), Vector(3, 4)))
```
</div>

リストが3つの要素を持つ場合はどうなるだろうか?

```tut:book:silent
listSequence(List(Vector(1, 2), Vector(3, 4), Vector(5, 6)))
```

<div class="solution">
入力のリストに3つの要素がある場合は、結果は各要素から`Int`を1つずつとったときの全ての組み合わせとなる:

```tut:book
listSequence(List(Vector(1, 2), Vector(3, 4), Vector(5, 6)))
```
</div>

#### 演習: Option のトラバース

`Option`を利用したコードの例を示す:

```tut:book:silent
import cats.instances.option._ // for Applicative

def process(inputs: List[Int]) =
  listTraverse(inputs)(n => if(n % 2 == 0) Some(n) else None)
```

このメソッドの返り値の型は何か? 次の入力に対しては、どんな結果を返すだろうか?

```tut:book:silent
process(List(2, 4, 6))
process(List(1, 2, 3))
```

<div class="solution">
`listTraverse`に与えている引数の型は`List[Int]`と `Int => Option[Int]`であるから、返り値の型は`Option[List[Int]]`となる。
`Option`もまたモナドなので、semigroupal の`combine`関数は`flatMap`を利用して定義されている。
したがってセマンティクスはフェイルファストなエラー処理となる:
すべての入力が偶数ならば、リストの出力が得られる。そうでなければ`None`が返る:

```tut:book
process(List(2, 4, 6))
process(List(1, 2, 3))
```
</div>

#### 演習: Validated のトラバース

最後になるが、`Validated`を利用したコード例を示す:

```tut:book:silent
import cats.data.Validated
import cats.instances.list._ // for Monoid

type ErrorsOr[A] = Validated[List[String], A]

def process(inputs: List[Int]): ErrorsOr[List[Int]] =
  listTraverse(inputs) { n =>
    if(n % 2 == 0) {
      Validated.valid(n)
    } else {
      Validated.invalid(List(s"$n is not even"))
    }
  }
```

このメソッドは、次の入力に対してどんな結果を返すだろうか?

```tut:book:silent
process(List(2, 4, 6))
process(List(1, 2, 3))
```

<div class="solution">
この場合の返り値の型は`ErrorsOr[List[Int]]`であり、これを展開すると`Validated[List[String], List[Int]]`となる。
validated における semigroupal の`combine`のセマンティクスはエラーを蓄積するというものなので、結果はすべての要素が偶数であるようなリスト、または条件に合わなかった数についての詳細を含むエラーのリストとなる。

```tut:book
process(List(2, 4, 6))
process(List(1, 2, 3))
```
</div>
