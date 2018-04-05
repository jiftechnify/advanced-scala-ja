## 余談: 部分的単一化(Partial Unification) {#sec:funtors:partial:unification}

[@sec:functors:more-examples]節では、奇妙なコンパイルエラーを見た。
次のコードは、`-Ypartial-unification`というコンパイラフラグが有効ならば申し分なくコンパイルする:

```tut:book:silent
import cats.Functor
import cats.instances.function._ // for Functor
import cats.syntax.functor._     // for map

val func1 = (x: Int)    => x.toDouble
val func2 = (y: Double) => y * 2
```

```tut:book
val func3 = func1.map(func2)
```

しかし、このフラグを指定しなければコンパイルに失敗する:

```scala
val func3 = func1.map(func2)
// <console>: error: value map is not a member of Int => Double
//        val func3 = func1.map(func2)
                            ^
```

明らかに、「部分的単一化(partial unification)」はコンパイラの追加の振る舞いであり、それがなければこのコードがコンパイルに失敗するようなものである。
少し時間をかけて、この振る舞いについて説明し、問題への対処法について考えよう。

### 型コンストラクタの単一化

上の`func1.map(func2)`のような式がコンパイルを通るためには、コンパイラは`Function1`に対する`Functor`インスタンスを探す必要がある。
しかし、`Functor`は型パラメータを1つだけとるような型コンストラクタしか受け付けない:

```scala
trait Functor[F[_]] {
  def map[A, B](fa: F[A])(func: A => B): F[B]
}
```

一方`Function1`は2つの型パラメータをとる(関数の引数の型と、結果の型だ):

```scala
trait Function1[-A, +B] {
  def apply(arg: A): B
}
```

コンパイラは、`Functor`に渡す正しいカインドを持つ型コンストラクタを作り出すために、`Function1`の2つの型パラメータのうち1つを固定しなければならない。
これには2つの選択肢がある:

```tut:book:silent
type F[A] = Int => A
type F[A] = A => Double
```

**我々は** 前者が正しい選択だと知っている。
しかし、古いバージョンの Scala コンパイラはこの推論を行うことができなかった。
[SI-2712][link-si2712]として知られるこの悪名高い制限が、コンパイラが異なる数の型パラメータを持つ型コンストラクタを「単一化」できないようにしている。
このコンパイラの制限は現在は修正されたものの、この修正を有効にするには`build.sbt`にコンパイラフラグを追加する必要がある:

```scala
scalaOptions += "-Ypartial-unification"
```

### 左から右への消去

Scala コンパイラにおける部分的単一化は、型パラメータを左から右の順で固定していく。
上の例でいえば、コンパイラは`Int => Double`という型の`Int`を固定し、`Int => ?`という型の関数に対する`Functor`を探す:

```tut:book:silent
type F[A] = Int => A

val functor = Functor[F]
```

この「左から右への消去」は、`Function1`や`Either`のような型に対する`Functor`のような、多くの状況でうまくいく:

```tut:book:silent
import cats.instances.either._ // for Functor
```

```tut:book
val either: Either[String, Int] = Right(123)

either.map(_ + 1)
```

しかし、左から右への消去が正しい選択でない状況もある。
ひとつの例としては、[Scalactic][link-scalactic]にある`Or`型が挙げられる。これは`Either`を「左バイアス」にしたものに等しい型である:

```scala
type PossibleResult = ActualResult Or Error
```

もうひとつの例は、`Function1`に対する`Contravariant`だ。

`Function1`に対する共変な`Functor`が`andThen`のような左から右への関数合成を表現する一方で、`Contravariant`は`compose`のような右から左への合成を表現する。
言い換えれば、以下の式はすべて等価である:

```tut:book:silent
val func3a: Int => Double =
  a => func2(func1(a))

val func3b: Int => Double =
  func2.compose(func1)
```

```tut:book:fail:silent
// 仮説的な例。実際にはコンパイルを通らない:
val func3c: Int => Double =
  func2.contramap(func1)
```

しかし、これを実際に試してみると、コンパイルに失敗する:

```tut:book:silent
import cats.syntax.contravariant._ // for contramap
```

```tut:book:fail
val func3c = func2.contramap(func1)
```

ここでの問題は、`Function1`に対する`Contravariant`は返り値の型を固定し、引数の型を変数のままにするということである。コンパイラは、以下のコードや図[@fig:functors:function-contramap-type-chart]に示すように、型パラメータを「右から左へ」消去しなければならない:

```scala
type F[A] = A => Double
```

![型チャート: Function1のcontramap](src/pages/functors/function-contramap.pdf+svg){#fig:functors:function-contramap-type-chart}

コンパイラは左から右への消去しかできないので、これに失敗する。
`Function1`の型パラメータを入れ替えた型エイリアスを作ることで、この問題を解決できる:

```tut:book:silent
type <=[B, A] = A => B

type F[A] = Double <= A
```

`func2`を`<=`のインスタンスとして定義しなおせば、必要な順番で型パラメータの消去が行われるようになり、望みどおり`contramap`を呼び出せるようになる:

```tut:book:silent
val func2b: Double <= Double = func2
```

```tut:book
val func3c = func2b.contramap(func1)
```

`func2`と`func2b`の違いは単なる構文的な違いである---両方とも同じ値を指し、型エイリアスは完全に互換性がある。
信じられないかもしれないが、コンパイラに問題を解決するのに十分なヒントを与えるにはこの単純な変形を行うだけで十分なのだ。

このような、右から左への消去を行う必要がある状況は稀である。
多くの、複数の型パラメータを持つ型コンストラクタは右バイアスであるように設計されている。これはコンパイラがサポートする左から右への消去のみを必要とするので、追加で何かをする必要はない。

しかし、`Y-partial-unification`や型パラメータの消去順序の「癖」に関する知識は、上で見てきたような奇妙な状況に出くわした際に役立つはずだ。
