# ファンクタ

本章では、`List`や`Option`、その他多種多様な文脈の中における演算の連なりを表現することを可能にする抽象概念である、 **ファンクタ** を調べていく。
ファンクタそれ自身はあまり便利なものではないが、 **モナド** や **アプリカティブファンクタ** のような特殊化されたファンクタは、Cats における抽象化のうち最もよく使われるものである。

## ファンクタの例 {#sec:functors:examples}

ざっくり言えば、ファンクタとは`map`メソッドを持つすべてである。
このメソッドを持つたくさんの型をご存知だろう。いくつか例を挙げるとすれば、`Option`、`List`、`Either`などがある。

`List`の要素に対して反復処理を行うときが、`map`とのはじめての出会いとなることが多い。
しかし、ファンクタのことを理解するには、このメソッドを他の視点から考える必要がある。
`map`を、リストを探索するものとしてではなく、一度に中身のすべてを変換するものだと考えてみよう。
関数を指定すれば、`map`はそれぞれの要素にその関数を適用してくれる。
値は変化するが、リストの構造はそのまま残る:

```tut:book
List(1, 2, 3).map(n => n + 1)
```

同様に、`Option`の上で`map`を行えば、`Some`か`None`かという文脈を変えることなく、中身だけを変換することができる。
同じ原則が`Either`の`Left`と`Right`という文脈についても当てはまる。
図[@fig:functors:list-option-either-type-chart]に示した型シグネチャの共通パターンに沿った、変換に関する一般的な考え方が、異なるデータ型の間の`map`の振る舞いを1つに結びつける。

![型チャート: List、Option、Eitherにおけるmap](src/pages/functors/list-option-either-map.pdf+svg){#fig:functors:list-option-either-type-chart}

`map`は文脈をそのまま残すので、あるデータ構造の要素に対する複数の計算を繋げるために、`map`を繰り返し呼び出すことができる:

```tut:book
List(1, 2, 3).
  map(n => n + 1).
  map(n => n * 2).
  map(n => n + "!")
```

`map`は、反復処理のパターンではなく、関係するデータ型によって規定される、ある詳細を無視した値に対する計算を繋げるための方法だと考えたほうがよい:

- `Option`---値が存在するかもしれないし、存在しないかもしれない
- `Either`---値が存在するか、エラーが発生した
- `List`---0個以上の値が存在する

## さらなるファンクタの例 {#sec:functors:more-examples}

`List`、`Option`、`Either`の`map`メソッドは、関数をその場ですぐに適用する。
しかし、計算を繋げるという考え方はもっと一般的なものだ。
違ったやり方でこのパターンを適用する、いくつかの他のファンクタの振る舞いについて詳しく見ていこう。

**フューチャー(Future)**

`Future`は非同期計算をキューに入れることで繋ぎ、前の計算が終わった時点でその計算を適用するようなファンクタである。
`Future`の`map`メソッドの型シグネチャは、図[@fig:functors:future-type-chart]が示すとおり、上で挙げたものと同じ形をしている。
しかし、その振る舞いは全く異なる。

![型チャート: Futureにおけるmap](src/pages/functors/future-map.pdf+svg){#fig:functors:future:type:chart}

`Future`を扱う際は、その内部状態には何の保証もない。
包まれた計算は実行中かもしれないし、完了しているかもしれないし、はたまた中断されているかもしれない。
もし`Future`の計算が完了していれば、変換関数は即座に実行される。
そうでなければ、内部のスレッドプールがその関数呼び出しをキューに入れ、後ほどそれを実行する。
**いつ** 関数が呼び出されるかを知ることはできないが、**どんな順番で** 呼び出されるかについては分かる。
このようにして、`Future`は`List`、`Option`、そして`Either`の例で見たような計算の連鎖という振る舞いを提供している。

```tut:book:silent
import scala.concurrent.{Future, Await}
import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.duration._

val future: Future[String] =
  Future(123).
    map(n => n + 1).
    map(n => n * 2).
    map(n => n + "!")
```

```tut:book
Await.result(future, 1.second)
```

<div class="callout callout-info">
**Future の参照透過性(referential transparency)**

Scala の`Future`は **参照透過** ではないので、純粋関数プログラミングの良い例ではないということに気をつけてほしい。
`Future`は常に結果を計算してキャッシュする。この振る舞いを改変する方法はない。
これは、`Future`を副作用を持つ計算を包むのに利用した際、想定外の結果が発生するということを意味する。
例えば:

```tut:book:silent
import scala.util.Random

val future1 = {
  // 固定のシードで乱数を初期化:
  val r = new Random(0L)

  // nextIntは次の乱数に移動するという副作用を持つ:
  val x = Future(r.nextInt)

  for {
    a <- x
    b <- x
  } yield (a, b)
}

val future2 = {
  val r = new Random(0L)

  for {
    a <- Future(r.nextInt)
    b <- Future(r.nextInt)
  } yield (a, b)
}
```

```tut:book
val result1 = Await.result(future1, 1.second)
val result2 = Await.result(future2, 1.second)
```

理想的には`result1`と`result2`は同じ値を持つべきだ。
しかし、`future1`の計算が`nextInt`を一度だけ呼び出すのに対し、`future2`の計算は`nextInt`を2回呼び出す。
`nextInt`は毎回異なる結果を返すので、それぞれの場合で得られる結果は異なってしまう。

このような食い違いが、`Future`と副作用を含むプログラムの意味を考えるのを難しいものにする。
`Future`の振る舞いには他にも問題点がある。ユーザがプログラムを実行する時点を指定することができず、常に計算が即座に開始してしまうという振る舞いが問題である。
詳しくは Rob Norrisによる[素晴らしい Reddit の投稿][link-so-future]を参照のこと。
</div>

`Future`は参照透過ではないが、もう1つ、よく似たデータ型で参照透過なものを見ることになるだろう。
お分かりいただけるだろうか…

**関数(?!)**

1引数の関数もまたファンクタであることが分かっている。
これを理解するには、型を少しいじる必要がある。
`A => B`という型の関数は2つの型パラメータを持つ。引数の型`A`と結果の型`B`だ。
これを望む形に矯正するには、引数の型を固定し、結果の型だけを変えられるように変形する:

 - `X => A`型の関数から始め、
 - `A => B`型の関数を与えると…
 - `X => B`型の関数を返すようにする

`X => A`という型に`MyFunc[A]`という別名を付ければ、これは本章で見てきた他の例と同じパターンを持った型であることが分かる。
図[@fig:functors:function-type-chart]もこのことを示している:

 - `MyFunc[A]`型から始め、
 - `A => B`型の関数を与えると…
 - `MyFunc[B]`型の値(関数)を返す

![型チャート: Function1におけるmap](src/pages/functors/function-map.pdf+svg){#fig:functors:function-type-chart}

言い換えれば、`Function1`に対する「変換(mapping)」とは関数合成のことだ:

```tut:book:silent
import cats.instances.function._ // for Functor
import cats.syntax.functor._     // for map
```

```tut:book:silent
val func1: Int => Double =
  (x: Int) => x.toDouble

val func2: Double => Double =
  (y: Double) => y * 2
```

```tut:book
(func1 map func2)(1)     // composition using map
(func1 andThen func2)(1) // composition using andThen
func2(func1(1))          // composition written out by hand
```

これは、連鎖する計算という一般的なパターンとどのように関係しているのだろうか?
関数合成は **まさに** 計算の連鎖であると考えることができる。
まず1つの計算だけを行う関数から始めて、`map`するごとにもう1つの計算を連鎖に追加すると考える。
`map`を呼び出した時点では、実際の計算は **実行されない** が、最終的に得られた関数に引数を渡すことで、連鎖に含まれるすべての計算が順に実行される。
これを`Future`と同様の、計算をあとで実行する待機列に追加する操作と考えることができる:

```tut:book:silent
val func =
  ((x: Int) => x.toDouble).
    map(x => x + 1).
    map(x => x * 2).
    map(x => x + "!")
```

```tut:book
func(123)
```

<div class="callout callout-warning">
**部分的単一化(partial unification)**

上の例を動作させるには、次のようなコンパイラオプションを`build.sbt`に追加する必要がある:

```scala
scalaOptions += "Ypartial-unification"
```

そうしないと、コンパイルエラーが発生する:

```scala
func1.map(func2)
// <console>: error: value map is not a member of Int => Double
//        func1.map(func2)
                ^
```

[@sec:functors:partial-unificaiton]節で、なぜこのようなことが起きるのかについて詳しく見ていく。
</div>

## ファンクタの定義

ここまで見てきたすべての例はファンクタである。これは計算の連鎖をカプセル化するクラスだ。
形式的には、`(A => B) => F[B]`という型の`map`演算を持つような型`F[A]`をファンクタと呼ぶ。
一般的な型チャートを図[@fig:functors:functor-type-chart]に示す。
![型チャート: 一般的なファンクタのmap](src/pages/functors/generic-map.pdf+svg){#fig:functors:functor-type-chart}

Cats は`Functor`を[`cats.Functor`][cats.Functor]型クラスという形で表現しており、そのメソッドは少し違った見た目をしている。
`map`メソッドは最初の`F[A]`を変換関数とは別に引数として受け取る。
簡略化した定義は以下の通りである:

```scala
package cats
```

```tut:book:silent
import scala.language.higherKinds

trait Functor[F[_]] {
  def map[A, B](fa: F[A])(f: A => B): F[B]
}
```

`F[_]`のような構文をここで初めて見る読者もいるだろう。**型コンストラクタ** と **高階カインド型** について考えるために、少し回り道をしよう。
`scala.language`インポートについても説明する。

<div class="callout callout-warning">
**ファンクタの法則**

ファンクタは、多くの小さな計算を1つずつ連鎖しても、`map`を行う前にそれらを1つの大きな関数として組み合わせたとしても、意味が等しくなるということを保証する。
これを確かにするためには、次の法則を満たさなければならない:

**恒等関数の法則**: 恒等関数を引数に`map`を呼び出した結果は、何もしなかった場合と同じでなければならない:

```scala
fa.map(a => a) == fa
```

**合成の法則**: `f`と`g`の2つの関数を合成した関数で`map`した結果は、`f`で`map`してから`g`で`map`したときの結果と同じでなければならない:

```scala
fa.map(g(f(_))) == fa.map(f).map(g)
```
</div>

## 余談: 高階カインドと型コンストラクタ

カインドは、「型の型」のようなものだ。
カインドは、型に空いた「穴」の数を表している。
1つも穴を持たない通常の型と、穴を埋めることで新たな型を生み出すことができる「型コンストラクタ」は区別される。

例えば、`List`は1つの穴を持つ型コンストラクタである。
型パラメータを指定することでこの穴を埋め、`List[Int]`や`List[A]`のような通常の型を作ることができる。
`List`は「型コンストラクタ」で、`List[A]`は「型」だ:

```scala
List    // 1つの型パラメータをとる「型コンストラクタ」
List[A] // 型パラメータを使って生み出された「型」
```

これは関数と値との間の関係に似ている。
関数は引数を与えることで値を生み出す「値コンストラクタ」と考えることができる:

```scala
math.abs    // 1つの引数をとる「関数」
math.abs(x) // 引数を指定することで生み出された「値」
```

Scala では、型コンストラクタをアンダーバーを用いて宣言することができる。
一度宣言すれば、それをシンプルな名前で呼ぶことができる:

```scala
// アンダーバーを含む型コンストラクタ F を宣言:
def myMethod[F[_]] = {

  // アンダーバーをつけずに F を参照:
  val functor = Functor.apply[F]

  // ...
}
```

これは関数の定義では引数を指定するが、それを参照するときは引数名を省略するのに似ている:

```scala
// 引数を指定して f を宣言:
val f = (x: Int) => x * 2

// 引数なしで f を参照:
val f2 = f andThen f
```

型コンストラクタの知識があれば、Cats における`Functor`の定義は、`List`・`Option`・`Future`または型エイリアス`MyFunc`のような、1つの型パラメータをとるすべての型コンストラクタに対して`Functor`のインスタンスを作れるということを表しているのが分かるだろう。

<div class="callout callout-info">
**言語機能(language feature)のインポート**

Scala では、高階カインド型は発展的な言語機能とみなされている。
`A[_]`という構文で型コンストラクタを宣言する際は、高階カインド型の言語機能を「有効」にし、コンパイラの警告を抑制する必要がある。
先程見たように「language インポート」を利用することができる:

```scala
import scala.language.higherKinds
```

または、次の`scalacOptions`を`build.sbt`に追加してもよい:

```scala
scalacOptions += "-language:higherKinds"
```

本書では、可能な限り明示的に language インポートを利用する。
実用上は、`scalaOptions`フラグを用いたほうがシンプルで、冗長さを軽減できるだろう。
</div>
