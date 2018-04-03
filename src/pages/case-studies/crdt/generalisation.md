## 一般化

これで、分散型の、結果整合的な、インクリメントのみが可能なカウンタができた。
これはこれで有用な成果ではあるが、これで終わりにはしない。
本節では、自然数だけでなく、より多くのデータ型を扱えるようにするために、 GCounter の操作を抽象化することを試みる。

GCounter は自然数上の次のような演算を利用している:

- 加算(`increment`と`total`内)
- 最大値(`merge`内)
- 単位元 0 (`increment`と`merge`内)

ここにはモノイドのような何かがあると思われるかもしれないが、我々が依存している性質に空いてもっと詳細に見ていこう。

復習のためにいうと、[@sec:monoids]章で、モノイドは2つの法則を満たさなければならないことを学んだ。
二項演算`+`は結合的でなければならない:

`(a + b) + c == a + (b + c)`

そして、空の要素(empty)は単位元でなければならない:

`0 + a == a + 0 == a`

カウンタを初期化するためには、`increment`の単位元が必要だ。
一連の`merge`の連続によって正しい値が得られることを保証するには、結合性が必要となる。

`total`において、マシンごとのカウンタをどんな順番で合計しても正しい値が得られることを保証するために、我々は暗黙のうちに結合性と可換性を利用している。
また、カウンタを保持していないマシンの処理をスキップすることを可能にする、単位元の存在も仮定している。

`merge`の性質はより興味深い。
マシン`A`のカウンタをマシン`B`のカウンタとマージした結果と、逆にマシン`B`のカウンタをマシン`A`のカウンタとマージした結果が等しくなることを保証するために、可換性が必要である。
3つ以上のマシンのデータをマージした際に正しい結果が得られることを保証するには、結合性が必要となる。
空のカウンタを初期化するには単位元が必要だ。
最後に、2つのマシンが保持するマシンごとのカウンタのデータが同じならば、これらをマージしても間違った結果にならないことを保証するには、**冪等性(idempotency)** と呼ばれる追加の性質が必要となる。
冪等な操作は、複数回実行されてもその度に同じ結果を返すような操作である。
形式的には、次の関係が成り立つならば、二項演算`max`は冪等であるという:

```
a max a = a
```

まとめて書くと、次のようになる:

--------------------------------------------------------------------
  メソッド      単位元      可換          結合的        冪等
-------------- ----------- ------------- ------------- -------------
  `increment`   ○          ×             ○            ×

  `merge`       ○          ○            ○            ○

  `total`       ○          ○            ○            ×
--------------------------------------------------------------------

この表から、次のことが分かる。

- `increment`には、モノイドが必要である
- `total`には、可換なモノイドが必要である
- `merge`には、**有界半束(bounded semilattice)** とも呼ばれる、冪等で可換なモノイドが必要である

`increment`と`total`は同じ二項演算(加算)を利用しているので、両方が同じ可換モノイドを必要としているのが普通である。

この調査は、抽象に対する性質や法則について考えることの威力を示している。
これらの性質が特定できたので、GCounter で用いられている自然数を、これらの性質を満たすような演算を持つ任意のデータ型で置き換えることができる。
簡単な例として、和集合演算を二項演算、空集合を単位元とする「集合」が挙げられる。
`Int`を`Set[A]`に置き換えるだけで、GSetという型を作り出すことができる。

### 実装

この一般化を、コードの形で実装してみよう。
`increment`と`total`は可換なモノイドを、`merge`は有界半束(冪等で可換なモノイド)をそれぞれ要求することを思い出そう。

<!--
  BoundedSemiLattice 型クラスは Cats に存在している!
  書き換え検討中
-->
Cats は`Monoid`と`CommutativeMonoid`型クラスを提供しているが、有界半束の型クラスは提供していない[^spire]。
そこで、独自に`BoundedSemiLattice`型クラスを実装することにする。

```tut:book:silent
import cats.kernel.CommutativeMonoid

trait BoundedSemiLattice[A] extends CommutativeMonoid[A] {
  def combine(a1: A, a2: A): A
  def empty: A
}
```

有界半束は可換なモノイド(正確には、可換で冪等なモノイド)なので、上の実装では`BoundedSemiLattice[A]`は`CommutativeMonoid[A]`を継承している。

### 演習: 有界半束のインスタンス

`Int`と`Set`に対する`BoundedSemiLattice`型クラスのインスタンスを実装せよ。
実際には`、Int`に対するインスタンスは非負整数のみをとるべきだが、ここでは明示的に非負性をモデル化する必要はない。

<div class="solution">
インポートなしで暗黙のスコープに入るように、これらのインスタンスは`BoundedSemiLattice`のコンパニオンオブジェクトに配置するのが普通である。

`Set`に対するインスタンスを実装するのは、暗黙のメソッドを扱う良い練習になる。

```tut:book:invisible:reset
import cats.kernel.CommutativeMonoid
```

```tut:book:silent
object wrapper {
  trait BoundedSemiLattice[A] extends CommutativeMonoid[A] {
    def combine(a1: A, a2: A): A
    def empty: A
  }

  object BoundedSemiLattice {
    implicit val intInstance: BoundedSemiLattice[Int] =
      new BoundedSemiLattice[Int] {
        def combine(a1: Int, a2: Int): Int =
          a1 max a2

        val empty: Int =
          0
      }

    implicit def setInstance[A]: BoundedSemiLattice[Set[A]] =
      new BoundedSemiLattice[Set[A]]{
        def combine(a1: Set[A], a2: Set[A]): Set[A] =
          a1 union a2

        val empty: Set[A] =
          Set.empty[A]
      }
  }
}; import wrapper._
```
</div>

### 演習: ジェネリックな GCounter

`CommutativeMonoid`と`BoundedSemiLattice`を用いて、`GCounter`を一般化せよ。

これを実装する際は、実装を簡素化するために`Monoid`のメソッドや構文を利用する機会を探してみよう。
この演習は、コードの複数のレベルにおいて、型クラスによる抽象がどのように働くかの良い例となっている。
我々は大きな構成要素(CRDT)を設計するのにモノイドを利用しているのだが、それだけでなく、より小さな単位で、コードを短くしたりわかりやすくしたりするのにも役立つ。

<div class="solution">
動作する実装を以下に示す。
`merge`の定義において`|+|`を利用することで、マージやカウンタの最大値をとる操作が大きく単純化されていることに注目してほしい:

```tut:book:silent
import cats.instances.list._   // for Monoid
import cats.instances.map._    // for Monoid
import cats.syntax.semigroup._ // for |+|
import cats.syntax.foldable._  // for combineAll

final case class GCounter[A](counters: Map[String, A]) {
  def increment(machine: String, amount: A)
        (implicit m: CommutativeMonoid[A]): GCounter[A] = {
    val value = amount |+| counters.getOrElse(machine, m.empty)
    GCounter(counters + (machine -> value))
  }

  def merge(that: GCounter[A])
        (implicit b: BoundedSemiLattice[A]): GCounter[A] =
    GCounter(this.counters |+| that.counters)

  def total(implicit m: CommutativeMonoid[A]): A =
    this.counters.values.toList.combineAll
}
```
</div>

<!--
  BoundedSemiLattice 型クラスは Cats 内に存在しており、
  spireにはないので、書き換え検討中
-->
[^spire]: [Spire](https://github.com/non/spire)という、Cats と密接な関係にあるライブラリが、既にこの抽象化を提供している。
