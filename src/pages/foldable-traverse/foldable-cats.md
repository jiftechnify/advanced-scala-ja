### Cats における Foldable

Cats の`Foldable`は`foldLeft`と`foldRight`を型クラスとして抽象化している。
`Foldable`のインスタンスはこれらのメソッドを定義し、派生する多くのメソッドを持つ。
Cats は`List`、`Vector`、`Stream`、そして`Option`といった一握りの Scala データ型に対し、そのまま利用できる`Foldable`のインスタンスを提供している。

いつものように、`Foldable.apply`を利用してインスタンスを召喚し、その`foldLeft`の実装を直接呼び出すことができる。
`List`を用いた例を示す:

```tut:book:silent
import cats.Foldable
import cats.instances.list._ // for Foldable

val ints = List(1, 2, 3)
```

```tut:book
Foldable[List].foldLeft(ints, 0)(_ + _)
```

`Vector`や`Stream`のような他の順列に対しても同様に動作する。
`Option`を用いた例を示す。ここでは、`Option`を0個または1個の要素を持つ順列として扱う:

```tut:book:silent
import cats.instances.option._ // for Foldable

val maybeInt = Option(123)
```

```tut:book
Foldable[Option].foldLeft(maybeInt, 10)(_ + _)
```

#### 正しい右からの畳込み

`Foldable`の`foldRight`は、`foldLeft`とは違って`Eval`モナドを利用して定義されている:

```scala
def foldRight[A, B](fa: F[A], lb: Eval[B])
                     (f: (A, Eval[B]) => Eval[B]): Eval[B]
```

`Eval`を用いているということは、畳み込みが常に **スタック安全** であるということを意味する。たとえコレクションにおける`foldRight`のデフォルト実装がスタック安全でないとしてもである。
ストリームが長くなればなるほど、畳み込みに必要なスタックの量も増加する。
十分に大きなストリームは`StackOverflowError`を引き起こす:

```tut:book:silent
import cats.Eval
import cats.Foldable

def bigData = (1 to 100000).toStream
```

```tut:book:fail:invisible
// This example isn't printed... it's here to check the next code block is ok:
bigData.foldRight(0L)(_ + _)
```

```scala
bigData.foldRight(0L)(_ + _)
// java.lang.StackOverflowError ...
```

`Foldable`を利用することで、スタック安全な演算を強制し、オーバーフロー例外が発生しないようにすることができる:

```tut:book:silent
import cats.instances.stream._ // for Foldable
```

```tut:book:silent
val eval: Eval[Long] =
  Foldable[Stream].
    foldRight(bigData, Eval.now(0L)) { (num, eval) =>
      eval.map(_ + num)
    }
```

```tut:book
eval.value
```

<div class="callout callout-info">
**標準ライブラリにおけるスタック安全性**

標準ライブラリを利用する際、スタック安全性が問題となることはあまりない。
`List`や `Vector`のような、最もよく使われるコレクション型は、`foldRight`のスタック安全な実装を提供している:

```tut:book
(1 to 100000).toList.foldRight(0L)(_ + _)
(1 to 100000).toVector.foldRight(0L)(_ + _)
```

`Stream`を出動させたのは、この規則の例外であるためだ。
しかし、どんなデータ型を用いるとしても、`Eval`が助けとなるということを知っておくと便利だ。
</div>

#### モノイドによる畳み込み

`Foldable`は`foldLeft`の上で定義された多くの便利なメソッドを提供してくれる。
これらの多くは標準ライブラリにあるおなじみのメソッドを複写したものである。
例えば`find`、`exists`、`foeall`、`toList`、`isEmpty`、`nonEmpty`などが用意されている:

```tut:book
Foldable[Option].nonEmpty(Option(42))

Foldable[List].find(List(1, 2, 3))(_ % 2 == 0)
```

これらのなじみの深いメソッドに加え、Cats は`Monoid`を利用した2つのメソッドを提供している:

- `combineAll`(とその別名`fold`)は、順列の要素に対する`Monoid`を利用してすべての要素を組み合わせる

- `foldMap`はユーザが与えた関数で順列を変換し、その結果を`Monoid`によって組み合わせる

例えば、`List[Int]`の合計を計算するのに`combineAll`を利用することができる:

```tut:book:silent
import cats.instances.int._ // for Monoid
```

```tut:book
Foldable[List].combineAll(List(1, 2, 3))
```

あるいは、各`Int`を`String`に変換し、それらを連結するのに`foldMap`を利用することができる:

```tut:book:silent
import cats.instances.string._ // for Monoid
```

```tut:book
Foldable[List].foldMap(List(1, 2, 3))(_.toString)
```

最後になるが、ネストした順列を底まで巡回するために、`Foldable`を合成することができる:

```tut:book:silent
import cats.instances.vector._ // for Monoid

val ints = List(Vector(1, 2, 3), Vector(4, 5, 6))
```

```tut:book
(Foldable[List] compose Foldable[Vector]).combineAll(ints)
```

#### Foldable の構文

`Foldable`のすべてのメソッドは、[`cats.syntax.foldable`][cats.syntax.foldable]を用い、構文の形で利用することができる。
それぞれの場合で、`Foldable`におけるメソッドの第1引数は、メソッド呼び出しのレシーバに変わる:

```tut:book:silent
import cats.syntax.foldable._ // for combineAll and foldMap
```

```tut:book
List(1, 2, 3).combineAll

List(1, 2, 3).foldMap(_.toString)
```

<div class="callout callout-info">
**明示は暗黙に優る**

Scala は、レシーバに対して明示的に定義されたメソッドが利用できない場合に限り`Foldable`のインスタンスを用いる、ということを思い出そう。
例えば、次のコードでは `List`に定義された`foldLeft`が利用される:

```tut:book
List(1, 2, 3).foldLeft(0)(_ + _)
```

一方、次のようなジェネリックなコードでは`Foldable`が利用される:

```tut:book:silent
import scala.language.higherKinds
```

```tut:book
def sum[F[_]: Foldable](values: F[Int]): Int =
  values.foldLeft(0)(_ + _)
```

多くの場合はこの区別を心配する必要はない。これは仕様だ!
我々は呼び出したいメソッドを呼び出すだけでよい。あとはコンパイラが必要に応じて(コードが動作するのに必要な場合に限り)`Foldable`を自動で利用してくれる。
`foldRight`のスタック安全な実装が必要ならば、蓄積変数として`Eval`を利用するだけでコンパイラに Cats のメソッドを選択することを強制できる。
</div>
