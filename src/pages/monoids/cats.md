## Cats におけるモノイド

モノイドが何であるかについて分かったところで、Cats におけるモノイドの実装を見ていこう。
再び、**型クラス**、**型クラスのインスタンス**、そして **型クラスのインターフェイス** という3つの主要な観点から見ていく。

### モノイド型クラス

モノイドの型クラスは`cats.kernel.Monoid`で、これには[`cats.Monoid`][cats.kernel.Monoid]という別名がついている。
`Monoid`は`cats.kernel.Semigroup`を継承している。これにも[`cats.Semigroup`][cats.kernel.Semigroup]という別名がある。
Cats を利用する際は、通常は[`cats`][cats.package]パッケージから型クラスをインポートする:

```tut:book:silent
import cats.Monoid
import cats.Semigroup
```

<div class="callout callout-info">
**Cats Kernelとは?**

Cats Kernel は、Cats にあるすべての道具までは必要としないライブラリのために、一部の型クラスだけを提供する Cats のサブプロジェクトだ。
これらの核となる型クラスは、実装上は[`cats.kernel`][cats.kernel.package]パッケージで定義されているが、実用上区別する必要はめったにないので、これらには[`cats`][cats.package]という別名がつけられている。

本書に含まれる Cats Kernel の型クラスは、[`Eq`][cats.kernel.Eq]、[`Semigroup`][cats.kernel.Semigroup]、そして[`Monoid`][cats.kernel.Monoid]だ。
本書で紹介するその他のすべての型クラスは、メインの Cats プロジェクトの一部であり、[`cats`][cats.package]パッケージに直接定義されている。
</div>

### モノイドのインスタンス {#sec:monoid-instances}

`Monoid`は Cats における標準的なユーザインターフェイスの方針に従っている。コンパニオンオブジェクトは特定の型に対する型クラスのインスタンスを返す`apply`メソッドを持つ。
例えば、`String`に対するモノイドのインスタンスが必要なとき、スコープ内に正しい暗黙の値があれば、次のように書くことができる:

```tut:book:silent
import cats.Monoid
import cats.instances.string._ // for Monoid
```

```tut:book
Monoid[String].combine("Hi ", "there")
Monoid[String].empty
```

これは、次のコードと等価である:

```tut:book
Monoid.apply[String].combine("Hi ", "there")
Monoid.apply[String].empty
```

ご存知の通り、`Monoid`は`Semigroup`を継承している。
`empty`が必要ないならば、次のように書くこともできる:

```tut:book:silent
import cats.Semigroup
```

```tut:book
Semigroup[String].combine("Hi ", "there")
```

`Monoid`の型クラスインスタンスは、[第1章](#importing-default-instances)で説明したような標準的な方法で、`cats.instances`のもとにまとめられている。
例えば、`Int`のインスタンスが欲しければ、[`cats.instances.int`][cats.instances.int]からインポートできる:

```tut:book:silent
import cats.Monoid
import cats.instances.int._ // for Monoid
```

```tut:book
Monoid[Int].combine(32, 10)
```

同様にして、[`cats.instances.int`][cats.instances.int]と[`cats.instances.option`][cats.instances.option]からインポートしたインスタンスから、`Monoid[Option[Int]]`を組み立てることができる:

```tut:book:silent
import cats.Monoid
import cats.instances.int._    // for Monoid
import cats.instances.option._ // for Monoid
```

```tut:book
val a = Option(22)
val b = Option(20)

Monoid[Option[Int]].combine(a, b)
```

より包括的なインポートの一覧については、[第1章](#import-default-instances)を参照してほしい。

### モノイドの構文 {#sec:monoid-syntax}

Cats は、`|+|`演算子という形で`combine`メソッドのための構文を用意している。
`combine`は実装上`Semigroup`から来ているので、この構文を利用するには[`cats.syntax.semigroup`][cats.syntax.semigroup]からインポートする:

```tut:book:silent
import cats.instances.string._ // for Monoid
import cats.syntax.semigroup._ // for |+|
```

```tut:book
val stringResult = "Hi " |+| "there" |+| Monoid[String].empty
```

```tut:book:silent
import cats.instances.int._ // for Monoid
```

```tut:book
val intResult = 1 |+| 2 |+| Monoid[Int].empty
```

### 演習: すべてを足し算

*スーパーアダー(SuperAdder) バージョン3.5a-32* は、足し算にかけては世界一の、最先端のコンピュータだ。
プログラムのメインとなる関数は`def add(items: List[Int]): Int`というシグネチャを持つ。
悲惨な事故により、コードが消えてしまった! 世界を守るために、このメソッドを書き直してほしい!

<div class="solution">
単純に`foldLeft`で`0`と`+`演算子を利用することで、足し算を実装できる:

```tut:book:silent
def add(items: List[Int]): Int =
  items.foldLeft(0)(_ + _)
```

代わりに、`Monoid`を使って書くこともできるが、これはまだモノイドの有力な使い道とはいえない:

```tut:book:silent
import cats.Monoid
import cats.instances.int._    // for Monoid
import cats.syntax.semigroup._ // for |+|

def add(items: List[Int]): Int =
  items.foldLeft(Monoid[Int].empty)(_ |+| _)
```
</div>

よくやった! スーパーアダーの市場シェアは成長を続けており、追加機能の需要が高まっている。
人々は`List[Option[Int]]`の要素を足し合わせたいと思っている。
これが可能となるように、`add`の実装を修正しよう。
スーパーアダーのコードベースは最高にハイクオリティでなければならないので、コードの重複がないよう気をつけてほしい!

<div class="solution">
`Monoid`の出番だ。
`Int`の加算と`Option[Int]`のインスタンスの加算の両方を行う、ただ1つのメソッドが必要とされている。
これを、`Monoid`を暗黙の引数にとるジェネリックなメソッドとして書き下すことができる:

```tut:book:silent
import cats.Monoid
import cats.instances.int._    // for Monoid
import cats.syntax.semigroup._ // for |+|

def add[A](items: List[A])(implicit monoid: Monoid[A]): A =
  items.foldLeft(monoid.empty)(_ |+| _)
```

Scala の **コンテキスト境界(context bound)** 構文を利用して、より読みやすいコードを書くこともできる:

```tut:book:silent
def add[A: Monoid](items: List[A]): A =
  items.foldLeft(Monoid[A].empty)(_ |+| _)
```

要求の通り、このコードを`Int`型の値と`Option[Int]`の値の両方を足し合わせるのに利用できる:

```tut:book:silent
import cats.instances.int._ // for Monoid
```

```tut:book
add(List(1, 2, 3))
```

```tut:book:silent
import cats.instances.option._ // for Monoid
```

```tut:book
add(List(Some(1), None, Some(2), None, Some(3)))
```

すべての要素が`Some`であるようなリストを足し合わせようとすると、コンパイルエラーになることに注意しよう:

```tut:book:fail
add(List(Some(1), Some(2), Some(3)))
```

これは、リストの型が`List[Some[Int]]`と推論される一方で、Cats は`Option[Int]`に対する`Monoid`のインスタンスしか生成しないために起こる。
この問題への対処については後述する。
</div>

スーパーアダーは、POS(point-of-sale、販売時点情報管理)市場に参入しようとしている。
次は、この`Orders`を足し合わせたい:

```tut:book:silent
case class Order(totalCost: Double, quantity: Double)
```

今すぐにでもコードをリリースしなければならないので、`add`に修正を加えている暇はない。
`Order`を足し合わせることができるようにせよ!

<div class="solution">
簡単だ---`Order`に対するモノイドのインスタンスを定義するだけでいい!

```tut:book:silent
implicit val monoid: Monoid[Order] = new Monoid[Order] {
  def combine(o1: Order, o2: Order) =
    Order(
      o1.totalCost + o2.totalCost,
      o1.quantity + o2.quantity
    )

  def empty = Order(0, 0)
}
```
</div>
