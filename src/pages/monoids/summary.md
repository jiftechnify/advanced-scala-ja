## まとめ

我々はこの章において大きな進歩を遂げた---即ち、関数プログラミング的な洒落た名前を持つ、はじめての型クラスを理解した:

 - `Semigroup`(半群) は、足し合わせたり、組み合わせたりする操作を表す
 - `Monoid`(モノイド) は、`Semigroup`を単位元、もしくは「ゼロ」という要素によって拡張したもの

`Semigroup`や`Monoid`は、型クラスそれ自身、関心のある型に対するそのインスタンス、そして`|+|`演算子をもたらす半群の構文をインポートすることで利用できる:

```tut:book:silent
import cats.Monoid
import cats.instances.string._ // for Monoid
import cats.syntax.semigroup._ // for |+|
```

```tut:book
"Scala" |+| " with " |+| "Cats"
```

正しいインスタンスがスコープの中にあれば、何でも足し合わせることができる:

```tut:book:silent
import cats.instances.int._    // for Monoid
import cats.instances.option._ // for Monoid
```

```tut:book
Option(1) |+| Option(2)
```

```tut:book:silent
import cats.instances.map._ // for Monoid

val map1 = Map("a" -> 1, "b" -> 2)
val map2 = Map("b" -> 3, "d" -> 4)
```

```tut:book
map1 |+| map2
```

```tut:book:silent
import cats.instances.tuple._  // for Monoid


val tuple1 = ("hello", 123)
val tuple2 = ("world", 321)
```

```tut:book
tuple1 |+| tuple2
```

`Monoid`のインスタンスを持つ任意の型に対して動作するジェネリックなコードを書くこともできる:

```tut:book:silent
def addAll[A](values: List[A])
      (implicit monoid: Monoid[A]): A =
  values.foldRight(monoid.empty)(_ |+| _)
```

```tut:book
addAll(List(1, 2, 3))
addAll(List(None, Some(1), Some(2)))
```

`Monoid`は Cats への偉大な入り口である。
簡単に理解でき、利用するのも難しくない。
しかし、モノイドは Cats が可能にしてくれる抽象化の「氷山」の一角に過ぎない。
次章では、皆大好き`map`メソッドを型クラスで「擬人化」した、 **ファンクタ** を見ていく。
本当に面白いのはこれからだ!
