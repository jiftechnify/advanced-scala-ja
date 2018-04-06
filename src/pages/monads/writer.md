## Writer モナド {#writer-monad}

[`cats.data.writer`][cats.data.Writer]は、計算と一緒にログを記録することを可能にするモナドである。
これを用いて、メッセージ、エラー、または計算に関する追加のデータを記録し、最終結果とは別にログとして取り出すことができる。

`Writer`の一般的な利用法は、通常の命令的なロギング技術では別々の計算からのメッセージが混じり合ってしまうような、マルチスレッド計算のステップの連続を記録する、というものである。
`Writer`によって計算ログはその結果に紐付けられるので、並行に計算を実行してもログが混じり合うことはない。

<div class="callout callout-info">
**Cats のデータ型**

`Writer`は[`cats.data`][cats.data.package]パッケージにある中ではじめて見るデータ型だ。
このパッケージは、便利なセマンティクスをもつ様々な型クラスのインスタンスを提供している。
他の`cats.data`にあるインスタンスの例としては、次章で見るモナド変換子や、[@sec:applicatives]章で出会うことになる[`Validated`][cats.data.Validated]型が挙げられる。
</div>

### Writer の生成と値の取り出し

`Writer[W, A]`は2つの値を持ち運ぶ:
`W`型の **ログ** と `A`型の **結果** だ。
以下のようにして、各種の型の値から`Writer`を生成できる:

```tut:book:silent
import cats.data.Writer
import cats.instances.vector._ // for Monoid
```

```tut:book
Writer(Vector(
  "It was the best of times",
  "it was the worst of times"
), 1859)
```

コンソールに表示される型は、期待するような`Writer[Vector[String], Int]`ではなく、実際には`WriterT[Id, Vector[String], Int]`となることに注意してほしい。
コード再利用の精神から、Cats は`Writer`は`WriterT`というもう1つの型によって実装されている。
`WriterT`は **モナド変換子** と呼ばれる新しい概念の一例である。これについては次章で取り上げる。

今はこの詳細を気にしないことにしよう。
`Writer`は`WriterT`の型エイリアスなので、`WriterT[Id, W, A]`を`Writer[W, A]`のように読むことができる:

```scala
type Writer[W, A] = WriterT[Id, W, A]
```

便宜のために、Cats はログのみまたは結果のみを指定して `Writer`を生成する方法を提供している。
結果だけがある場合、標準的な`pure`構文を利用できる。
これを利用するには、Cats に空のログを生成する方法を知らせるためにスコープ内に`Monoid[W]`を持っている必要がある:

```tut:book:silent
import cats.instances.vector._   // for Monoid
import cats.syntax.applicative._ // for pure

type Logged[A] = Writer[Vector[String], A]
```

```tut:book
123.pure[Logged]
```

記録したいログだけがあり、結果がない場合は[`cats.syntax.writer`][cats.syntax.writer]にある`tell`構文を利用して`Writer[Unit]`を作ることができる:

```tut:book:silent
import cats.syntax.writer._ // for tell
```

```tut:book
Vector("msg1", "msg2", "msg3").tell
```

結果とログの両方がある場合は、`Writer.apply`か[`cats.syntax.writer`][cats.syntax.writer]にある`writer`構文を利用できる:

```tut:book:silent
import cats.syntax.writer._ // for writer
```

```tut:book
val a = Writer(Vector("msg1", "msg2", "msg3"), 123)
val b = 123.writer(Vector("msg1", "msg2", "msg3"))
```

`Writer`に記録された結果とログを、それぞれ`value`メソッドと`written`メソッドによって取り出すことができる:

```tut:book
val aResult: Int =
  a.value
val aLog: Vector[String] =
  a.written
```

`run`メソッドを利用して、両方の値を同時に取り出すこともできる:

```tut:book
val (log, result) = b.run
```

### Writer の合成と変換

`Writer`の中のログは、`map`や`flatMap`を呼び出しても保存される。
`flatMap`は元の`Writer`のログに追記しつつ、ユーザが連鎖させた関数に計算を追加する。
よって、`Vector`のような効率的に追加や結合が可能な型をログに用いるのは良い習慣である:

```tut:book
val writer1 = for {
  a <- 10.pure[Logged]
  _ <- Vector("a", "b", "c").tell
  b <- 32.writer(Vector("x", "y", "z"))
} yield a + b

writer1.run
```

`map`や`flatMap`による結果の変換に加えて、`mapWritten`メソッドによる`Writer`野中のログの変換も可能である:

```tut:book
val writer2 =  writer1.mapWritten(_.map(_.toUpperCase))

writer2.run
```

`bimap`や`mapBoth`を利用して、ログと結果の両方を同時に変換することもできる。
`bimap`は2つの関数を引数にとり、1つをログ、もう1つを結果に適用する。
`mapBoth`は、2つの引数を受け取るようなただ1つの関数をとる:

```tut:book
val writer3 = writer1.bimap(
  log => log.map(_.toUpperCase),
  res => res * 100
)

writer3.run

val writer4 = writer1.mapBoth { (log, res) =>
  val log2 = log.map(_ + "!")
  val res2 = res * 1000
  (log2, res2)
}

writer4.run
```

最後に、`reset`メソッドを用いてログを消去でき、また`swap`メソッドを用いてログと結果を入れ替えることができる:

```tut:book
val writer5 = writer1.reset

writer5.run

val writer6 = writer1.swap

writer6.run
```

### 演習: お前の働きぶりを見せてくれ

`Writer`はマルチスレッド環境におけるロギングに有用である。
このことを、階乗の計算(とロギング)を行うことで確かめよう。

以下の`factorial`関数は階乗を計算し、実行の際の中間ステップを出力する。
`slowly`ヘルパー関数は、下のような非常に小さな例であっても、実行に一定の時間がかかるようにするものである:

```tut:book:silent
def slowly[A](body: => A) =
  try body finally Thread.sleep(100)

def factorial(n: Int): Int = {
  val ans = slowly(if(n == 0) 1 else n * factorial(n - 1))
  println(s"fact $n $ans")
  ans
}
```

出力は以下のようになる---単調に増加する値の列だ:

```tut:book
factorial(5)
```

いくつかの階乗の計算を並列に開始すると、ログメッセージは標準出力に交互に表示されるようになる。
これにより、どのメッセージがどの計算からきたものかが分かりづらくなる:

```tut:book:silent
import scala.concurrent._
import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.duration._
```

```scala
Await.result(Future.sequence(Vector(
  Future(factorial(3)),
  Future(factorial(3))
)), 5.seconds)
// fact 0 1
// fact 0 1
// fact 1 1
// fact 1 1
// fact 2 2
// fact 2 2
// fact 3 6
// fact 3 6
// res14: scala.collection.immutable.Vector[Int] =
//   Vector(120, 120)
```

<!--
HACK: tut isn't capturing stdout from the threads above,
so i gone done hacked it.
-->

`factorial`を書き換えて、`Writer`の中にログメッセージを記録するようにせよ。
これによって、並行計算において計算ごとに別々のログを記録できることを示せ。

<div class="solution">
まず、`pure`構文を使えるようにするために、`Writer`に対する型エイリアスを定義することから始める:

```tut:book:silent
import cats.data.Writer
import cats.syntax.applicative._ // for pure

type Logged[A] = Writer[Vector[String], A]
```

```tut:book
42.pure[Logged]
```

さらに`tell`構文をインポートする:

```tut:book:silent
import cats.syntax.writer._ // for tell
```

```tut:book
Vector("Message").tell
```

最後に`Vector`に対する`Semigroup`のインスタンスをインポートする。
これは`Logged`に対して`map`や`flatMap`を行うのに必要である:

```tut:book:silent
import cats.instances.vector._ // for Semigroup
```

```tut:book
41.pure[Logged].map(_ + 1)
```

これらがスコープの中にある状態において、`factorial`の定義は次のようになる:

```tut:book:silent
def factorial(n: Int): Logged[Int] =
  for {
    ans <- if(n == 0) {
             1.pure[Logged]
           } else {
             slowly(factorial(n - 1).map(_ * n))
           }
    _   <- Vector(s"fact $n $ans").tell
  } yield ans
```

`factorial`を呼び出す際は、ログと階乗の結果を取り出すために、返り値に対し`run`を実行する必要がある:

```tut:book
val (log, res) = factorial(5).run
```

次のように、混ざり合うことを心配することなく独立にログを記録しながら、いくつかの`factorial`を並列に実行することができる:

```tut:book
val Vector((logA, ansA), (logB, ansB)) =
  Await.result(Future.sequence(Vector(
    Future(factorial(3).run),
    Future(factorial(5).run)
  )), 5.seconds)
```
</div>
