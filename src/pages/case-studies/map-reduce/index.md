# 事例: Map-Reduce {#map-reduce}

ここでは、`Monoid`、`Functor`、その他多数のおまけを利用した、シンプルだが強力な並列処理フレームワークを実装する。

Hadoop を利用したことがあれば、そうでなくとも「ビッグデータ」を扱ったことがあれば、[MapReduce][link-map-reduce]という言葉を耳にしたことがあるだろう。
これは、複数のマシン(または「ノード」)のクラスタの間で並列にデータを処理するためのプログラミングモデルである。
名前が示唆する通り、このモデルは Scalaの、または`Functor`型クラスの`map`と同様の働きをする **map(変換)** フェーズと、Scala では通常`fold`[^hadoop-shuffle]と呼ばれる **reduce(集約)** フェーズからなる。

[^hadoop-shuffle]: Hadoopには shuffle フェーズもあるが、ここでは考えない。

## *map* と *fold* の並列化

`map`の一般的なシグネチャは、`F[A]`型の値に`A => B`型の関数を適用すると、`F[B]`型の値を返すというものであった:

![型チャート: ファンクタの map](src/pages/functors/generic-map.pdf+svg){#fig:map-reduce:functor-type-chart}

`map`は、順列のそれぞれの要素を独立に変換する。
別々の要素に適用される変換の間に依存性はないので、`map`は簡単に並列化できる(型に反映されていない副作用を内部で利用していないと仮定すれば、`A => B`という関数の型シグネチャがこれを示していることになる)。

`fold`についてはどうだろうか?
`Foldable`のインスタンスによってこのステップを実装できる。
すべてのファンクタが foldable のインスタンスを併せ持つわけではないが、両方の型クラスに属する任意のデータ型の上で map-reduce システムを実装できる。
集約のステップは、分配された`map`の結果に対し`foldLeft`を行うというものになる。

![型チャート: fold](src/pages/foldable-traverse/generic-foldleft.pdf+svg){#fig:map-reduce:foldleft-type-chart}

集約ステップを分配することで、探索の順序の制御を失うことになる。
すべての要素の集約が左から右に行われるとは限らない---いくつかの部分列に対し左から右への集約を行い、それから結果を組み合わせることもできる。
正しさを保証するには、集約演算が **結合的** でなければならない:

```scala
reduce(a1, reduce(a2, a3)) == reduce(reduce(a1, a2), a3)
```

結合性があれば、各ノードの部分列が最初のデータセットと同じ順に並ぶようにする限り、ノードたちに仕事を好きなように分配することができる。

畳み込み演算は、計算の初期値となる`B`型の要素を必要とする。
畳み込みは任意の数の並列ステップに分割されうるので、その初期値は計算の結果に影響を与えるべきではない。
これはつまり、その初期値は **単位元** 要素である必要があるということだ:

```scala
reduce(seed, a1) == reduce(a1, seed) == a1
```

まとめると、並列畳み込みは次の条件を満たす場合に正しい結果を生成する:

- 集約関数が結合的である
- その集約関数の単位元を初期値として与えている

このパターンは何かに似ていないだろうか?
そう、本書で最初に見た型クラスである`Monoid`に帰ってきたのだ。
我々がモノイドの重要性にはじめて気づいた、というわけではない。
[map-reduce のためのモノイド・デザインパターン][link-map-reduce-monoid]が、Twitter の[Summingbird][link-summingbird]のような、近年のビッグデータシステムの核となっているのだ。

## *foldMap* を実装する

`Foldable`を説明した際に、少し`foldMap`について触れた。
これは`foldLeft`と`foldRight`の上にある派生演算のひとつである。
しかし、`Foldable`を利用する代わりに、自分で`foldMap`を再実装してみることにする。これは map-reduce の構造に対する有用な洞察を与えるだろう。

まず、`foldMap`のシグネチャを書き下してみよう。
これは次のような引数を受け取る:

 - `Vector[A]`型の順列
 - `A => B`型の関数。ただし、`B`型に対する`Monoid`が存在する

この型シグネチャを完成させるには、暗黙の引数かコンテキスト境界を追加する必要があるだろう。

<div class="solution">
```tut:book:silent
import cats.Monoid

/** シングルスレッドの map-reduce 関数。
  * `values`を`func`で変換し、`Monoid[B]`を利用して集約する。
  */
def foldMap[A, B: Monoid](values: Vector[A])(func: A => B): B =
  ???
```
</div>

さて、`foldMap`の本体を実装しよう。
必要なステップの道標として、図[@fig:map-reduce:fold-map] のフローを用いよ:

1. `A`型の要素を持つ順列から始める
2. それを変換して`B`型の要素を持つ順列を生成する
3. `Monoid`を利用して、全要素を1つの`B`型の値に集約する

![*foldMap* のアルゴリズム](src/pages/case-studies/map-reduce/fold-map.pdf+svg){#fig:map-reduce:fold-map}

参考のために、いくつかの出力例を挙げる:

```tut:book:invisible
import cats.Monoid
import cats.syntax.semigroup._ // for |+|

def foldMap[A, B: Monoid](values: Vector[A])(func: A => B): B =
  values.foldLeft(Monoid[B].empty)(_ |+| func(_))
```

```tut:book:silent
import cats.instances.int._ // for Monoid
```

```tut:book
foldMap(Vector(1, 2, 3))(identity)
```

```tut:book:silent
import cats.instances.string._ // for Monoid
```

```tut:book
// String への変換は連結モノイドを利用する:
foldMap(Vector(1, 2, 3))(_.toString + "! ")

// String を変換して String を生成する:
foldMap("Hello world!".toVector)(_.toString.toUpperCase)
```

<div class="solution">
`B`に対する`Monoid`を受け取るために、型シグネチャを変更する必要がある。
この変更によって、[@sec:monoid-syntax]節で説明した`Monoid`の`empty`と`|+|`構文が利用できるようになる:

```tut:book:silent
import cats.Monoid
import cats.instances.int._    // for Monoid
import cats.instances.string._ // for Monoid
import cats.syntax.semigroup._ // for |+|

def foldMap[A, B: Monoid](as: Vector[A])(func: A => B): B =
  as.map(func).foldLeft(Monoid[B].empty)(_ |+| _)
```

このコードを少し変更し、すべてを1ステップで実行するようにできる:

```tut:book:silent
def foldMap[A, B: Monoid](as: Vector[A])(func: A => B): B =
  as.foldLeft(Monoid[B].empty)(_ |+| func(_))
```
</div>

## *foldMap* を並列化する

`foldMap`のシングルスレッド実装は手に入ったので、これを並列に実行するために仕事を分配する方法について見ていこう。
構成要素としてシングルスレッド版の`foldMap`を用いる。

図[@fig:map-reduce:parallel-fold-map]に示すような map-reduce クラスタに仕事を分配する方法をシミュレートする、マルチ CPU 実装を書いていく:

1. 処理しなければならないすべてのデータからなる初期リストから始める
2. データを複数のバッチに分割し、各CPUに1つずつ送る
3. CPUたちはバッチレベルの map フェーズを実行する
4. CPUたちはバッチレベルの reduce フェーズを実行し、各バッチの局所的な結果を生成する
5. 各バッチからの結果を集約し、1つの最終結果を得る

![*parallelFoldMap* のアルゴリズム](src/pages/case-studies/map-reduce/parallel-fold-map.pdf+svg){#fig:map-reduce:parallel-fold-map}

Scala は、複数のスレッドに仕事を分配するのに利用できる、いくつかの簡単なツールを提供している。
実装に[並列コレクションライブラリ][link-parallel-collections]を使うこともできるが、もっと深入りし、`Future`を利用してアルゴリズムを自分で実装することに挑戦してみよう。

### *Future* 、スレッドプール、実行コンテキスト(ExecutionContext)

我々は、既に`Future`のモナド的な性質についてよく知っている。
簡単な復習のため、また Scala の future が裏側でどのようにスケジュールされているのかを説明するために、少し紙面を割くことにする。

`Future`は、暗黙の`ExecutionContext`型の引数によって定められたスレッドプール上で実行される。
`Future`を生成するときはいつでも(`Future.apply`またはその他のコンビネータを利用する場合も)、スコープ内に暗黙の`ExecutionContext`を持っている必要がある:

```tut:book:silent
import scala.concurrent.Future
import scala.concurrent.ExecutionContext.Implicits.global
```

```tut:book
val future1 = Future {
  (1 to 100).toList.foldLeft(0)(_ + _)
}

val future2 = Future {
  (100 to 200).toList.foldLeft(0)(_ + _)
}
```

この例では、`ExecutionContext.Implicits.global`をインポートした。
この組み込みのコンテキストは、マシンが持つ CPU 1つにつき1つのスレッドを持つようなスレッドプールを割り当てる。
`Future`を生成する際、この`ExecutionContext`がその実行をスケジュールする。
プール内に空きスレッドがあれば、`Future`は即座に実行を開始する。
近年のほとんどのマシンは少なくとも2つの CPU を持つので、上の例における`future1`と`future2`は並列に実行されるだろう。

いくつかのコンビネータは、他の`Future`の結果に基づいて実行をスケジュールするような新しい`Future`を生成する。
例えば、`map`や`flatMap`メソッドは、入力値が計算され、かつ CPU が利用可能になるとすぐに実行されるように計算をスケジュールする。

```tut:book
val future3 = future1.map(_.toString)

val future4 = for {
  a <- future1
  b <- future2
} yield a + b
```

[@sec:traverse]節で見たように、`Future.sequence`を利用して`List[Future[A]]`を`Future[List[A]]`に変換することができる:

```tut:book
Future.sequence(List(Future(1), Future(2), Future(3)))
```

または、`Traverse`のインスタンスを利用することもできる:

```tut:book:silent
import cats.instances.future._ // for Applicative
import cats.instances.list._   // for Traverse
import cats.syntax.traverse._  // for sequence
```

```tut:book
List(Future(1), Future(2), Future(3)).sequence
```

どちらの場合も、`ExecutionContext`が必要となる。
最後に、`Await.result`を利用して結果が利用可能になるまで`Future`をブロックすることができる:

```tut:book:silent
import scala.concurrent._
import scala.concurrent.duration._
```

```tut:book
Await.result(Future(1), 1.second) // 結果を待つ
```

`Future`に対する`Monad`や`Monoid`は、`cats.instances.future`にある:

```tut:book:silent
import cats.{Monad, Monoid}
import cats.instances.int._    // for Monoid
import cats.instances.future._ // for Monad and Monoid

Monad[Future].pure(42)

Monoid[Future[Int]].combine(Future(1), Future(2))
```

### 仕事を分割する

`Future`に関する記憶を新たにしたところで、仕事をバッチに分割する方法について見ていこう。
Java 標準ライブラリの API を呼び出すことで、マシンが持つ利用可能な CPU の数を調べることができる:

```tut:book
Runtime.getRuntime.availableProcessors
```

`grouped`メソッドを利用して、順列(実際には`Vector`を実装するすべてのもの)を分割することができる。
これを利用して仕事を分割し、各 CPU にバッチを割り振る:

```tut:book
(1 to 10).toList.grouped(3).toList
```

### *parallelFoldMap* を実装する

`parallelFoldMap`という名前の、`foldMap`の並列バージョンを実装せよ。
型シグネチャは次の通り:

```tut:book:silent
def parallelFoldMap[A, B : Monoid]
      (values: Vector[A])
      (func: A => B): Future[B] = ???
```

上で説明したテクニックを利用して、仕事を 1つの CPU あたり1つのバッチに分割せよ。
各バッチを並列に動作するスレッドで処理せよ。
全体のアルゴリズムを確認するのに必要なら、図[@fig:map-reduce:parallel-fold-map]を見返すとよい。

ボーナス問題として、上で実装した`foldMap`を利用して各 CPU でバッチを処理しするように変更してみよ。

<div class="solution">
`map`と`fold`のそれぞれを分けて書いた、注釈付きの解答を以下に示す:

```tut:book:silent
import scala.concurrent.duration.Duration

def parallelFoldMap[A, B: Monoid]
      (values: Vector[A])
      (func: A => B): Future[B] = {
  // 各 CPU に渡す要素の数を計算する
  val numCores  = Runtime.getRuntime.availableProcessors
  val groupSize = (1.0 * values.size / numCores).ceil.toInt

  // 各 CPU に1つずつグループを生成する
  val groups: Iterator[Vector[A]] =
    values.grouped(groupSize)

  // 各グループを foldMap する future を生成する
  val futures: Iterator[Future[B]] =
    groups map { group =>
      Future {
        group.foldLeft(Monoid[B].empty)(_ |+| func(_))
      }
    }

  // 最終結果を計算するために各グループの結果を foldMap する
  Future.sequence(futures) map { iterable =>
    iterable.foldLeft(Monoid[B].empty)(_ |+| _)
  }
}

val result: Future[Int] =
  parallelFoldMap((1 to 1000000).toVector)(identity)
```

```tut:book
Await.result(result, 1.second)
```

より簡潔な解答を得るために、`foldMap`の定義を再利用することができる。
図[@fig:map-reduce:parallel-fold-map]におけるステップ3と4の局所的な変換と集約が、実際には`foldMap`の1回の呼び出しに等価であることに注意すれば、次のように全体のアルゴリズムを短縮できる:

```tut:book:silent
def parallelFoldMap[A, B: Monoid]
      (values: Vector[A])
      (func: A => B): Future[B] = {
  val numCores  = Runtime.getRuntime.availableProcessors
  val groupSize = (1.0 * values.size / numCores).ceil.toInt

  val groups: Iterator[Vector[A]] =
    values.grouped(groupSize)

  val futures: Iterator[Future[B]] =
    groups.map(group => Future(foldMap(group)(func)))

  Future.sequence(futures) map { iterable =>
    iterable.foldLeft(Monoid[B].empty)(_ |+| _)
  }
}

val result: Future[Int] =
  parallelFoldMap((1 to 10000000).toVector)(identity)
```

```tut:book
Await.result(result, 1.second)
```
</div>

### 他の Cats と *parallelFoldMap*

上では自分で`foldMap`を実装したが、このメソッドは[@sec:foldable]節で見た`Foldable`型クラスの一部としても利用可能である。

Cats の`Foldable`と`Traverse`型クラスを用いて`parallelFoldMap`を再実装せよ。

<div class="solution">
完全を期すため、すべての必要なインポートを再宣言する:

```tut:book:silent:reset
import cats.Monoid
import cats.Foldable
import cats.Traverse

import cats.instances.int._    // for Monoid
import cats.instances.future._ // for Applicative and Monad
import cats.instances.vector._ // for Foldable and Traverse

import cats.syntax.semigroup._ // for |+|
import cats.syntax.foldable._  // for combineAll and foldMap
import cats.syntax.traverse._  // for traverse

import scala.concurrent._
import scala.concurrent.duration._
import scala.concurrent.ExecutionContext.Implicits.global
```

可能な限りメソッドの本体を Cats に委譲する`parallelFoldMap`の実装は以下のようになる:

```tut:book:silent
def parallelFoldMap[A, B: Monoid]
      (values: Vector[A])
      (func: A => B): Future[B] = {
  val numCores  = Runtime.getRuntime.availableProcessors
  val groupSize = (1.0 * values.size / numCores).ceil.toInt

  values
    .grouped(groupSize)
    .toVector
    .traverse(group => Future(group.toVector.foldMap(func)))
    .map(_.combineAll)
}
```

```tut:book:silent
val future: Future[Int] =
  parallelFoldMap((1 to 1000).toVector)(_ * 1000)
```

```tut:book
Await.result(future, 1.second)
```

`vector.grouped`の呼び出しは`Iterable[Iterator[Int]]`を返す。
Cats が理解できる形にデータを変換するために、`toVector`の呼び出しをコードに散りばめている。
`traverse`を呼び出し、バッチごとに1つの`Int`値を持つ`Future[Vector[Int]]`を生成する。
そして`map`を呼び出し、`Foldable`の`combineAll`メソッドを利用してバッチごとの結果を結合する。
</div>

## まとめ

この事例では、クラスタとして実行される map-reduce を模倣するようなシステムを実装した。
アルゴリズムは3つのステップに従う:

1. データをバッチに分割し、各「ノード」に1つのバッチを送る
2. 局所的な map-reduce を各バッチに対して実行する
3. モノイドの結合演算を利用して各結果を組み合わせる

我々のおもちゃのシステムは、Hadoop のような現実世界の map-reduce システムが持つバッチ処理の振る舞いをエミュレートする。
しかし、実際にはすべての仕事を1つのマシン上で実行している。ノード間の通信はとるに足らないものである。
この場合、リストの効率的な並列処理を得るためにデータをバッチに分割する必要はない。
単純に`Functor`を利用して変換し、`Monoid`を利用して集約するだけでいい。

バッチ処理の戦略にかかわらず、`Monoid`を利用した変換と集約は、加算や文字列の連結のような単純な仕事に限定されない、強力で普遍的なフレームワークである。
データサイエンティストが日常的な分析において行うほとんどの仕事は、モノイドにキャストできる。
次のものはすべてモノイドだ:

- ブルームフィルタのような近似的集合
- HyperLogLog のような、集合の要素数を推定するアルゴリズム
- 確率的勾配降下法のようなベクトル演算
- t-digest のような、分位点(quantile)を推定するアルゴリズム

枚挙にいとまがない。
