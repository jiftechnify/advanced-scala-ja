## GCounter を型クラスに抽象化する

ここまで、`BoundedSemiLattice`と`CommutativeMonoid`のインスタンスを持つ任意の値を扱うことができるジェネリックな GCounter を作ってきた。
しかしまだ、マシン ID と値の対応の表現については特定の表現に依存している。
この制限は必要なく、実際のところそれを抽象化できれば便利だろう。
単純な`Map`から関係データベースまで、様々なキー・バリューストアを扱えるようにしたい。

`GCounter`の型クラスを定義すれば、様々な具体実装を抽象化することができる。
これにより、例えば、データの耐久性よりも性能を重視したくなった際に、永続的記憶装置をインメモリの記憶装置にシームレスに置き換えることができるようになる。

これを実装する方法はいくつかある。
ひとつの方針は、`CommutativeMonoid`と`BoundedSemiLattice`に依存する`GCounter`型クラスを定義するというものだ。
マップの抽象におけるキーと値の型を表現する、 **2つの** 型パラメータを持つ型コンストラクタを受け取るような型クラスを定義することになる。

```tut:book:invisible
import scala.language.higherKinds
import cats.kernel.CommutativeMonoid

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

```tut:book:silent
object wrapper {
  trait GCounter[F[_,_], K, V] {
    def increment(f: F[K, V])(k: K, v: V)
          (implicit m: CommutativeMonoid[V]): F[K, V]

    def merge(f1: F[K, V], f2: F[K, V])
          (implicit b: BoundedSemiLattice[V]): F[K, V]

    def total(f: F[K, V])
          (implicit m: CommutativeMonoid[V]): V
  }

  object GCounter {
    def apply[F[_,_], K, V]
          (implicit counter: GCounter[F, K, V]) =
      counter
  }
}; import wrapper._
```

`Map`に対する、この型クラスのインスタンスを定義してみよう。
ケースクラス版の`GCounter`のコードを再利用し、小さな変更を行うだけで十分なはずだ。

<div class="solution">
このインスタンスの完全なコードを以下に示す。
これをグローバルな暗黙スコープに配置するには、この定義を`GCounter`のコンパニオンオブジェクトの中に書くとよい:

```tut:book:silent
import cats.instances.list._   // for Monoid
import cats.instances.map._    // for Monoid
import cats.syntax.semigroup._ // for |+|
import cats.syntax.foldable._  // for combineAll

implicit def mapInstance[K, V]: GCounter[Map, K, V] =
  new GCounter[Map, K, V] {
    def increment(map: Map[K, V])(key: K, value: V)
          (implicit m: CommutativeMonoid[V]): Map[K, V] = {
      val total = map.getOrElse(key, m.empty) |+| value
      map + (key -> total)
    }

    def merge(map1: Map[K, V], map2: Map[K, V])
          (implicit b: BoundedSemiLattice[V]): Map[K, V] =
      map1 |+| map2

    def total(map: Map[K, V])
          (implicit m: CommutativeMonoid[V]): V =
      map.values.toList.combineAll
  }
```
</div>

実装したインスタンスは次のように利用できるはずだ:

```tut:book:silent
import cats.instances.int._ // for Monoid

val g1 = Map("a" -> 7, "b" -> 3)
val g2 = Map("a" -> 2, "b" -> 5)

val counter = GCounter[Map, String, Int]
```

```tut:book
val merged = counter.merge(g1, g2)
val total  = counter.total(merged)
```

型クラスのインスタンスに対するこの実装方針は、少し物足りないものだ。
実装の構造は多くのインスタンスに対して同様のものになるはずだが、これではコードを再利用できない。

## キー・バリューストアの抽象化

ひとつの解決策は、キー・バリューストアの考え方を型クラスという形で捉え、`KeyValueStore`のインスタンスを持つような任意の型に対する`GCounter`インスタンスを生成するというものだ。
そのような型クラスのコードは以下のようになる:

```tut:book:silent
trait KeyValueStore[F[_,_]] {
  def put[K, V](f: F[K, V])(k: K, v: V): F[K, V]

  def get[K, V](f: F[K, V])(k: K): Option[V]

  def getOrElse[K, V](f: F[K, V])(k: K, default: V): V =
    get(f)(k).getOrElse(default)

  def values[K, V](f: F[K, V]): List[V]
}
```

`Map`に対するこの型クラスのインスタンスを実装せよ。

<div class="solution">
このインスタンスのコードを以下に示す。
これをグローバルな暗黙スコープに配置するには、`KeyValueStore`のコンパニオンオブジェクトの中にこの定義を書くとよい:

```tut:book:silent
implicit val mapInstance: KeyValueStore[Map] =
  new KeyValueStore[Map] {
    def put[K, V](f: Map[K, V])(k: K, v: V): Map[K, V] =
      f + (k -> v)

    def get[K, V](f: Map[K, V])(k: K): Option[V] =
      f.get(k)

    override def getOrElse[K, V](f: Map[K, V])
        (k: K, default: V): V =
      f.getOrElse(k, default)

    def values[K, V](f: Map[K, V]): List[V] =
      f.values.toList
  }
```
</div>

この型クラスがあれば、そのインスタンスを持つようなデータ型を拡張する構文を実装することができる:

```tut:book:silent
implicit class KvsOps[F[_,_], K, V](f: F[K, V]) {
  def put(key: K, value: V)
        (implicit kvs: KeyValueStore[F]): F[K, V] =
    kvs.put(f)(key, value)

  def get(key: K)(implicit kvs: KeyValueStore[F]): Option[V] =
    kvs.get(f)(key)

  def getOrElse(key: K, default: V)
        (implicit kvs: KeyValueStore[F]): V =
    kvs.getOrElse(f)(key, default)

  def values(implicit kvs: KeyValueStore[F]): List[V] =
    kvs.values(f)
}
```

これで、`implicit def`を用いて、`KeyValueStore`と`CommutativeMonoid`のインスタンスを持つような任意のデータ型に対して`GCounter`のインスタンスを生成できるようになった:

```tut:book:silent
implicit def gcounterInstance[F[_,_], K, V]
    (implicit kvs: KeyValueStore[F], km: CommutativeMonoid[F[K, V]]) =
  new GCounter[F, K, V] {
    def increment(f: F[K, V])(key: K, value: V)
          (implicit m: CommutativeMonoid[V]): F[K, V] = {
      val total = f.getOrElse(key, m.empty) |+| value
      f.put(key, total)
    }

    def merge(f1: F[K, V], f2: F[K, V])
          (implicit b: BoundedSemiLattice[V]): F[K, V] =
      f1 |+| f2

    def total(f: F[K, V])(implicit m: CommutativeMonoid[V]): V =
      f.values.combineAll
  }
```

この事例の完全なコードはかなり長いものとなったが、その多くは型クラス上の演算の構文を定めるためのボイラープレートである。
[Simulacrum][link-simulacrum]や[Kind Projector][link-kind-projector]のようなコンパイラプラグインを利用することで、これを削減できる。
