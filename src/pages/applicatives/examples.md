## 別の型に適用された Semigroupal

`Semigroupal`はどんな型にも思い通りの振る舞いを提供するとは限らない。特に、`Monad`のインスタンスを同時に持つ型に対してはその傾向が強い。
他の型における例を見ていこう。

**Future**

`Future`に対するセマンティクスは、逐次実行とは対照的な、並行実行となる:

```tut:book:silent
import cats.Semigroupal
import cats.instances.future._ // for Semigroupal
import scala.concurrent._
import scala.concurrent.duration._
import scala.concurrent.ExecutionContext.Implicits.global
import scala.language.higherKinds

val futurePair = Semigroupal[Future].
  product(Future("Hello"), Future(123))
```

```tut:book
Await.result(futurePair, 1.second)
```

2つの`Future`は生成された瞬間に実行を開始するので、`product`を呼び出したときには既に結果の計算が行われている。
決まった数の`Future`を綴じ合わせるのに apply 構文を利用できる:

```tut:book:silent
import cats.syntax.apply._ // for mapN

case class Cat(
  name: String,
  yearOfBirth: Int,
  favoriteFoods: List[String]
)

val futureCat = (
  Future("Garfield"),
  Future(1978),
  Future(List("Lasagne"))
).mapN(Cat.apply)
```

```tut:book
Await.result(futureCat, 1.second)
```

**リスト**

`Semigroupal`による`List`の合成は、思ってもみなかったような結果をもたらす。
次のようなコードはリストを **綴じ合わせる(zipする)** ように思われるが、実際には要素の直積が得られる:

```tut:book:silent
import cats.Semigroupal
import cats.instances.list._ // for Semigroupal
```

```tut:book
Semigroupal[List].product(List(1, 2), List(3, 4))
```

これには驚くかもしれない。
リストの綴じ合わせは、よりよく用いられる操作であることが多い。
このあとすぐ、なぜこのような振る舞いとなったのかを見る。

**Either**

本章のはじめに、フェイルファストとエラーの蓄積という対照的なエラー処理について議論した。
`Either`に適用された`product`は、フェイルファストではなくエラーを蓄積すると思うかもしれない。
驚くかもしれないが、ここでも、`product`は`flatMap`と同様のフェイルファストな振る舞いを実装している:

```tut:book:silent
import cats.instances.either._ // for Semigroupal

type ErrorOr[A] = Either[Vector[String], A]
```

```tut:book
Semigroupal[ErrorOr].product(
  Left(Vector("Error 1")),
  Left(Vector("Error 2"))
)
```

この例において、`product`は2つ目の引数を検査し、それもまた失敗だと気づくことができるはずなのに、最初の失敗を見つけた時点で停止する。

### モナドに適用された Semigroupal

`List`や`Either`における意外な結果の理由は、これらがどちらもモナドだというところにある。
一貫したセマンティクスのために、Cats の`Monad`(これは`Semigroupal`を継承している)は`map`と`flatMap`によって`product`の標準定義を提供しているのだ。
これは、多くのデータ型に対して、想定外であまり有用でない振る舞いをもたらす。
高い水準の抽象化においてセマンティクスの一貫性は重要だが、まだそんなことは知らない。

`Future`における結果は「錯覚」である。
`flatMap`は計算を逐次的に実行するので、`product`もやはり逐次実行を行う。
上で見たような並行実行が起きたのは、構成要素である`Future`が`product`を呼び出す前に実行を開始したためである。
これは、古典的な「生成してから flatMapする」パターンと等価である:

```tut:book:silent
val a = Future("Future 1")
val b = Future("Future 2")

for {
  x <- a
  y <- b
} yield (x, y)
```

それならば、いったいどうして`Semigroupal`などという手間のかかるものがあるのだろうか?
その答えは、`Semigroupal`(と`Applicative`)のインスタンスだが`Monad`ではないような、便利なデータ型を作ることができるからだ、というものである。
これで、`product`を様々な方法で自由に実装できる。
エラー処理のための新しいデータ型を見る際に、このことについて詳しく見ていく。

#### 演習: モナドの積

`flatMap`を用いて、`product`を実装せよ:

```tut:book:silent
import cats.Monad

def product[M[_]: Monad, A, B](x: M[A], y: M[B]): M[(A, B)] =
  ???
```

<div class="solution">
`map`と`flatMap`を次のように利用して`product`を実装できる:

```tut:book:silent
import cats.syntax.flatMap._ // for flatMap
import cats.syntax.functor._ // for map

def product[M[_]: Monad, A, B](x: M[A], y: M[B]): M[(A, B)] =
  x.flatMap(a => y.map(b => (a, b)))
```

このコードが次の for 内包表記と等価であるといっても、驚くことはないだろう:

```tut:book:silent
def product[M[_]: Monad, A, B](x: M[A], y: M[B]): M[(A, B)] =
  for {
    a <- x
    b <- y
  } yield (a, b)
```

この`flatMap`のセマンティクスが、`List`や`Either`における`product`の振る舞いの原因となっている:

```tut:book:silent
import cats.instances.list._ // for Semigroupal
```

```tut:book
product(List(1, 2), List(3, 4))
```

```tut:book:silent
type ErrorOr[A] = Either[Vector[String], A]
```

```tut:book
product[ErrorOr, Int, Int](
  Left(Vector("Error 1")),
  Left(Vector("Error 2"))
)
```

</div>
