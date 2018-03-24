## Foldable {#sec:foldable}

`Foldable`型クラスは、`List`、`Vector`、そして`Stream`のような順列ではおなじみの`foldLeft`と`foldRight`メソッドを捉えた型クラスである。
`Foldable`を利用して、様々な順列の型を扱うジェネリックな畳み込み処理を書くことができる。
また、新しい順列型を発明してコードに差し込むこともできる。
`Foldable`は、`Monoid`や`Eval`モナドの重要な利用例でもある。

### 畳み込み

まず、畳み込み(folding)という一般的な概念について少し復習しておこう。
畳み込みは、**蓄積変数(accumulator)** と **二項演算** を与えることで、順列の中の各要素を組み合わせることである:

```tut:book:silent
def show[A](list: List[A]): String =
  list.foldLeft("nil")((accum, item) => s"$item then $accum")
```

```tut:book
show(Nil)

show(List(1, 2, 3))
```

`foldLeft`メソッドは順列を再帰的に下っていく。
二項演算は各要素に対して繰り返し呼び出され、それぞれの呼び出しの結果が次の蓄積変数となる。
順列の最後に到達した際の最終的な蓄積変数が最終結果となる。

行おうとしている演算によっては、畳み込みをどちらの方向に向かって行うかが重要となることがある。
そのため、畳み込みには2つの標準的な変種がある:

- `foldLeft`は「左」から「右」へ(最初から最後へ)順列を辿る
- `foldRight`は「右」から「左」へ(最後から最初へ)順列を辿る

図[@fig:foldable-traverse:fold]は、それぞれの方向を説明している。

![foldLeft と foldRight の図解](src/pages/foldable-traverse/fold.pdf+svg){#fig:foldable-traverse:fold}


二項演算が可換(commutative)ならば、`foldLeft`と`foldRight`は等価になる。
例えば、`0`を蓄積変数、加算を二項演算として与えることで、どちらの方向で畳み込みを行っても`List[Int]`の要素の合計を計算できる:

```tut:book
List(1, 2, 3).foldLeft(0)(_ + _)
List(1, 2, 3).foldRight(0)(_ + _)
```

非可換な演算を与えた場合は、評価の順序が結果に違いをもたらす。
例えば、減算を用いて畳み込みを行うと、方向によって異なる結果が得られる:

```tut:book
List(1, 2, 3).foldLeft(0)(_ - _)
List(1, 2, 3).foldRight(0)(_ - _)
```

### 演習: 畳み込みによる「反射」

`foldLeft`と`foldRight`に空リストを蓄積変数、`::`を二項演算として与えて実行してみよ。それぞれの場合でどんな結果が得られるだろうか?

<div class="solution">
左から右への畳み込みは、リストを反転させる:

```tut:book
List(1, 2, 3).foldLeft(List.empty[Int])((a, i) => i :: a)
```

右から左への畳み込みは要素の順番を変えずにリストをコピーする:

```tut:book
List(1, 2, 3).foldRight(List.empty[Int])((a, i) => i :: a)
```

型エラーを避けるには、蓄積変数の型をよく考えて指定しなければならないことに注意してほしい。
蓄積変数の方が`Nil.type`または`List[Nothing]`と推論されるのを避けるため、ここでは`List.empty[Int]`を利用している:

```tut:book:fail
List(1, 2, 3).foldRight(Nil)(_ :: _)
```
</div>

### 演習: 畳み込みを他のメソッドの足場に

`foldLeft`と`foldRight`は非常に普遍的なメソッドである。
これらを利用することで、多くのよく知られた高レベルな順列の演算を実装することができる。
`List`の`map`、`flatMap`、`filter`、そして`sum`メソッドの代用品を`foldRight`によって実装し、このことを確かめよ。

<div class="solution">
解答は以下の通り:

```tut:book:silent
def map[A, B](list: List[A])(func: A => B): List[B] =
  list.foldRight(List.empty[B]) { (item, accum) =>
    func(item) :: accum
  }
```

```tut:book
map(List(1, 2, 3))(_ * 2)
```

```tut:book:silent
def flatMap[A, B](list: List[A])(func: A => List[B]): List[B] =
  list.foldRight(List.empty[B]) { (item, accum) =>
    func(item) ::: accum
  }
```

```tut:book
flatMap(List(1, 2, 3))(a => List(a, a * 10, a * 100))
```

```tut:book:silent
def filter[A](list: List[A])(func: A => Boolean): List[A] =
  list.foldRight(List.empty[A]) { (item, accum) =>
    if(func(item)) item :: accum else accum
  }
```

```tut:book
filter(List(1, 2, 3))(_ % 2 == 1)
```

`sum`については2つの定義を示す。
ひとつは`scala.math.Numeric`を利用したものだ(これは組み込みの機能を正確に再現している)...

```tut:book:silent
import scala.math.Numeric

def sumWithNumeric[A](list: List[A])
      (implicit numeric: Numeric[A]): A =
  list.foldRight(numeric.zero)(numeric.plus)
```

```tut:book
sumWithNumeric(List(1, 2, 3))
```

もうひとつの定義では、`cats.Monoid`を利用する(本書の内容としては、こちらのほうが適当だろう):

```tut:book:silent
import cats.Monoid

def sumWithMonoid[A](list: List[A])
      (implicit monoid: Monoid[A]): A =
  list.foldRight(monoid.empty)(monoid.combine)

import cats.instances.int._ // for Monoid
```

```tut:book
sumWithMonoid(List(1, 2, 3))
```
</div>
