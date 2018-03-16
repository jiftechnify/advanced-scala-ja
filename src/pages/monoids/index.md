# モノイドと半群 {#sec:monoids}

本節では、最初の型クラス、**モノイド(monoid)** と **半群(semigroup)** を探検していく。
これらの型クラスは、値同士を加算したり、組み合わせたりすることを可能にする。
`Int`・`String`・`List`・`Option`、他にもたくさんの型に対応するインスタンスが用意されている。
括りだすことのできる共通の原則を見つけるために、いくつかの簡単な型と演算から見ていくことにしよう。

**整数の足し算**

`Int`の足し算は、その結果が必ず他の`Int`になるという意味で **閉じた** 二項演算である:

```tut:book
2 + 1
```

また、すべての`Int`型の値`a`について`a + 0 == 0 + a == a`となるような、 **単位元(identity)** と呼ばれる要素が存在する:

```tut:book
2 + 0

0 + 2
```

足し算には他にも様々な性質がある。
例えば、常に結果が等しくなるので、どんな順番で値を足しても構わない。
この性質は **結合性(associativity)** として知られている:

```tut:book
(1 + 2) + 3

1 + (2 + 3)
```

**整数の掛け算**

足し算に成り立つ性質は、`0`の代わりに`1`を単位元とみなせば、掛け算にも成り立つ:

```tut:book
1 * 3

3 * 1
```

足し算と同様に、掛け算も結合的である:

```tut:book
(1 * 2) * 3

1 * (2 * 3)
```

**文字列の連結**

二項演算として文字列の連結を使うことで、`String`を「足し合わせる」こともできる:

```tut:book
"" ++ "Hello"

"Hello" ++ ""
```

文字列連結もまた、結合的である:

```tut:book
("One" ++ "Two") ++ "Three"

"One" ++ ("Two" ++ "Three")
```

順列(sequence)との類似性を示唆するために、通常使われる`+`の代わりに`++`を利用していることに注意してほしい。
順列の連結を二項演算、空の順列を単位元として用いることで、文字列の連結と同じことを他の型の値を要素に持つ順列に対しても行うことができる。

## モノイドの定義

ここまで、結合的な二項演算と単位元を持ついくつかの「足し算」を見てきた。
これがモノイドだと知っても何も驚かないだろう。
形式的にいえば、型`A`に対するモノイドは、以下の要素を持つものだ:

- `combine`と呼ばれる`(A, A) => A`型の演算
- `empty`と呼ばれる`A`型の要素

この定義はうまく Scala のコードに翻訳できる。
以下のコードは、Cats におけるモノイドの定義を簡略化したものである:

```tut:book:silent
trait Monoid[A] {
  def combine(x: A, y: A): A
  def empty: A
}
```

`combine`と`empty`を提供することに加えて、モノイドはいくつかの **法則** を満たさなければならない。
`A`型の任意の値`x`、`y`、`z`について、`combine`は結合的で、`empty`は単位元でなければならない:

```tut:book:silent
def associativeLaw[A](x: A, y: A, z: A)
    (implicit m: Monoid[A]): Boolean = {
  m.combine(x, m.combine(y, z)) ==
    m.combine(m.combine(x, y), z)
}

def identityLaw[A](x: A)
    (implicit m: Monoid[A]): Boolean = {
  (m.combine(x, m.empty) == x) &&
    (m.combine(m.empty, x) == x)
}
```

例えば、整数の引き算は結合的でないので、モノイドにはならない:

```tut:book
(1 - 2) - 3

1 - (2 - 3)
```

実際のところ、法則について考える必要があるのは自分の手で`Monoid`のインスタンスを書いているときだけだ。
法則を満たさないインスタンスは、Cats の他の機構と一緒に利用すると想定外の結果をもたらすことがあるため、危険なものである。
ほとんどの場合、Cats が提供するインスタンスは信頼でき、ライブラリの作者は自分が何をしているのかについて理解していると考えてよい。

## 半群の定義

半群は、単に「モノイドの`combine`の部分」だということができる。
多くの半群はモノイドでもあるが、いくつかのデータ型に対しては`empty`要素を定義することができない。
例えば、順列の連結や整数の足し算がモノイドであることを見てきたが、これらをそれぞれ空でないリスト・正の整数に限定すると、意味のある`empty`要素を定義することはできなくなる。
Cats には、`Semigroup`を実装しているが `Monoid`は実装していない、[`NonEmptyList`][cats.data.NonEmptyList]データ型がある。

Catsにおける[`Monoid`][cats.Monoid]の、より正確(だがやはり簡略化された)定義は以下の通りだ:

```tut:book:silent
trait Semigroup[A] {
  def combine(x: A, y: A): A
}

trait Monoid[A] extends Semigroup[A] {
  def empty: A
}
```

型クラスについて考察するとき、このような継承関係をよく見かけることになるだろう。
継承は、モジュール性を提供し、振る舞いの再利用を可能にする。
型`A`に対する`Monoid`を定義すれば、`Semigroup`がタダで手に入る。
同じように、型`Semigroup[B]`のパラメータを要求するメソッドに対して`Monoid[B]`を代わりに渡すこともできる。

## 演習: モノイドの真実

モノイドのいくつかの実例を見てきたが、まだ発見できていないたくさんのモノイドがある。
`Boolean`について考えよう。この型に対していくつモノイドを定義できるだろうか?
それぞれのモノイドについて、`combine`と`empty`を定義し、モノイドの法則が成り立つことを確かめよ。
取り掛かりとして、以下の定義を利用してよい:

```tut:book:silent
trait Semigroup[A] {
  def combine(x: A, y: A): A
}

trait Monoid[A] extends Semigroup[A] {
  def empty: A
}

object Monoid {
  def apply[A](implicit monoid: Monoid[A]) =
    monoid
}
```

<div class="solution">
`Boolean`に対するモノイドは4つもある!
1つ目は、`&&`演算子による **論理積(and)** を演算、`true`を単位元とするモノイド:

```tut:book:silent
implicit val booleanAndMonoid: Monoid[Boolean] =
  new Monoid[Boolean] {
    def combine(a: Boolean, b: Boolean) = a && b
    def empty = true
  }
```

2つ目は、`||`演算子による **論理和(or)** を演算、`false`を単位元とするモノイド:

```tut:book:silent
implicit val booleanOrMonoid: Monoid[Boolean] =
  new Monoid[Boolean] {
    def combine(a: Boolean, b: Boolean) = a || b
    def empty = false
  }
```

3つ目は、**排他的論理和(exclusive or)** を演算、`false`を単位元とするモノイド:

```tut:book:silent
implicit val booleanEitherMonoid: Monoid[Boolean] =
  new Monoid[Boolean] {
    def combine(a: Boolean, b: Boolean) =
      (a && !b) || (!a && b)

    def empty = false
  }
```

最後は、**排他的論理和の否定(exclusive nor)** を演算、`true`を単位元とするモノイドだ:

```tut:book:silent
implicit val booleanXnorMonoid: Monoid[Boolean] =
  new Monoid[Boolean] {
    def combine(a: Boolean, b: Boolean) =
      (!a || b) && (a || !b)

    def empty = true
  }
```

それぞれの場合で単位元の法則が成り立つことは簡単に示せる。
同様に、`combine`演算の結合性についても、すべての場合を列挙することで示すことができる。
</div>

## 演習: モノイド全員集合

集合(set) に対するモノイドや半群は、どのようなものになるだろうか?

<div class="solution">
集合の **和集合(union)** をとる演算は、空集合を単位元としてモノイドを成す:

```tut:book:silent
implicit def setUnionMonoid[A]: Monoid[Set[A]] =
  new Monoid[Set[A]] {
    def combine(a: Set[A], b: Set[A]): Set[A] = a union b
    def empty = Set.empty[A]
   }
```

型パラメータ`A`を受け取るためには、`setUnionMonoid`を値ではなくメソッドとして定義する必要がある。
この型パラメータによって、任意の型のデータを持つ`Set`に対する`Monoid`を召喚するのに同じ定義を使い回すことができるようになる:

```tut:book:silent
val intSetMonoid = Monoid[Set[Int]]
val strSetMonoid = Monoid[Set[String]]
```

```tut:book
intSetMonoid.combine(Set(1, 2), Set(2, 3))
strSetMonoid.combine(Set("A", "B"), Set("B", "C"))
```

集合の共通部分(intersection)をとる演算は半群を成すが、単位元が存在しないためモノイドにはならない:

```tut:book:silent
implicit def setIntersectionSemigroup[A]: Semigroup[Set[A]] =
  new Semigroup[Set[A]] {
    def combine(a: Set[A], b: Set[A]) =
      a intersect b
  }
```

集合の補集合(complement)や差集合(difference)をとる演算は結合的でないので、モノイドとも半群ともみなすことはできない。
しかし、対称差(symmetric difference、共通部分を除いた和集合)をとる演算は、やはり空集合を単位元としてモノイドを成す:

```tut:book:silent
implicit def symDiffMonoid[A]: Monoid[Set[A]] =
  new Monoid[Set[A]] {
    def combine(a: Set[A], b: Set[A]): Set[A] =
      (a diff b) union (b diff a)
    def empty: Set[A] = Set.empty
  }
```
</div>
