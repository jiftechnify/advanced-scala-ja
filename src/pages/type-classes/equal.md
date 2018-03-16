## 例: Eq

もう1つの便利な型クラス[`cats.Eq`][cats.kernel.Eq]を見て、この章を締めくくる。
`Eq`は、 **型安全な等価性** をサポートし、Scala 組み込みの`==`演算子を利用することによる苛立たしさに対処するために設計されている。

ほとんどの Scala 開発者は、一度は次のようなコードを書いたことがあるだろう:

```tut:book
List(1, 2, 3).map(Option(_)).filter(item => item == 1)
```

多くの読者はこんな分かりやすい間違いをしないだろうが、原理は理にかなっている。
`filter`節の条件式は`Int`と`Option[Int]`を比較しているため、常に`false`を返す。

これはプログラマの間違いだ。`item`は`1`ではなく`Some(1)`と比較するべきなのである。
しかし、技術的にいうとこれは型エラーではない。なぜなら`==`は、型にかかわらず、任意のオブジェクトの組に対して動作するからである。
`Eq`は等価性チェックに型安全性を加え、この問題に対処するように設計されている。

### 等価、自由、友愛

`Eq`を利用して、ある型のインスタンス同士の型安全な等価性を定義できる:

```scala
package cats

trait Eq[A] {
  def eqv(a: A, b: A): Boolean
  // eqvに基づくその他の具象メソッド...
}
```

[`cats.syntax.eq`][cats.syntax.eq]で定義されたインターフェイス構文は、`Eq[A]`のインスタンスがスコープに入っている限り、等価性チェックを行う2つのメソッドを提供する:

 - `===` は、2つのオブジェクトが等価かどうかを判定する
 - `=!=` は、2つのオブジェクトが非等価かどうかを判定する

### Int の比較

いくつか例を見ていこう。まず、型クラスをインポートする:

```tut:book:silent
import cats.Eq
```

次に、`Int`のインスタンスを取り込もう:

```tut:book:silent
import cats.instances.int._ // for Eq

val eqInt = Eq[Int]
```

`eqInt`を直接利用して等価性検査を行うこともできる:

```tut:book
eqInt.eqv(123, 123)
eqInt.eqv(123, 234)
```

Scala の `==`メソッドとは違って、`eqv`メソッドで異なる型のオブジェクト同士を比較しようとすると、コンパイルエラーとなる:

```tut:book:fail
eqInt.eqv(123, "234")
```

[`cats.syntax.eq`][cats.syntax.eq]にあるインターフェイス構文をインポートして、`===`や`=!=`メソッドを利用することもできる:

```tut:book:silent
import cats.syntax.eq._ // for === and =!=
```

```tut:book
123 === 123
123 =!= 234
```

やはり、異なる型の値同士を比較するとコンパイルエラーとなる:

```tut:book:fail
123 === "123"
```

### Option の比較 {#sec:type-classes:comparing-options}

さて、`Option[Int]`の比較という、もっと興味深い例を見ていこう。
型`Option[Int]`の値同士を比較するには、`Int`だけでなく`Option`に対する`Eq`のインスタンスもインポートする必要がある:

```tut:book:silent
import cats.instances.int._    // for Eq
import cats.instances.option._ // for Eq
```

比較を試してみる:

```tut:book:fail
Some(1) === None
```

ここでエラーが発生するのは、まだ型が一致していないためである。
`Int`と`Option[Int]`に対する`Eq`のインスタンスはスコープの中にある。しかし上の式では`Some[Int]`型の値を比較することになってしまう。
この問題を修正するには、引数の型を`Option[Int]`と指定し直す必要がある:

```tut:book
(Some(1) : Option[Int]) === (None : Option[Int])
```

標準ライブラリにある`Option.apply`と`Option.empty`メソッドを使えば、同じことをより親しみやすい形で表現できる:

```tut:book
Option(1) === Option.empty[Int]
```

もしくは、[`cats.syntax.option`][cats.syntax.option]に用意された特別な構文を使ってもいい:

```tut:book:silent
import cats.syntax.option._ // for some and none
```

```tut:book
1.some === none[Int]
1.some =!= none[Int]
```

### 自分だけの型を比較する

`(A, A) => Boolean`という型の関数を受け取って`Eq[A]`を返す`Eq.instance`メソッドを利用して、自分だけの`Eq`のインスタンスを定義できる:

```tut:book:silent
import java.util.Date
import cats.instances.long._ // for Eq
```

```tut:book:silent
implicit val dateEq: Eq[Date] =
  Eq.instance[Date] { (date1, date2) =>
    date1.getTime === date2.getTime
  }
```

```tut:book:silent
val x = new Date() // now
val y = new Date() // a bit later than now
```

```tut:book
x === x
x === y
```

### 演習: 等価、自由、友愛

`Cat`に対する`Eq`のインスタンスを実装せよ:

```tut:book:silent
final case class Cat(name: String, age: Int, color: String)
```

このインスタンスを用いて以下の2つのオブジェクトの組を比較し、等価性と非等価性を確かめよ:

```tut:book:silent
val cat1 = Cat("Garfield",   38, "orange and black")
val cat2 = Cat("Heathcliff", 33, "orange and black")

val optionCat1 = Option(cat1)
val optionCat2 = Option.empty[Cat]
```

<div class="solution">
まず必要なものをインポートする。
この演習では`Eq`型クラスと`Eq`のインターフェイス構文を利用する。
次のようにして、`Eq`のインスタンスをスコープの中に持ってくる:

```tut:book:silent
final case class Cat(name: String, age: Int, color: String)
```

`Cat`クラスはこれまでと同じものだ:

```scala
final case class Cat(name: String, age: Int, color: String)
```

`Int`と`String`に対する`Eq`のインスタンスをインポートし、`Eq[Cat]`を実装する:

```tut:book:silent
import cats.instances.int._    // for Eq
import cats.instances.string._ // for Eq

implicit val catEqual: Eq[Cat] =
  Eq.instance[Cat] { (cat1, cat2) =>
    (cat1.name  === cat2.name ) &&
    (cat1.age   === cat2.age  ) &&
    (cat1.color === cat2.color)
  }
```

最後に、サンプルアプリケーションの中で比較を行う:

```tut:book
val cat1 = Cat("Garfield",   38, "orange and black")
val cat2 = Cat("Heathcliff", 32, "orange and black")

cat1 === cat2
cat1 =!= cat2
```

```tut:book:silent
import cats.instances.option._ // for Eq
```

```tut:book
val optionCat1 = Option(cat1)
val optionCat2 = Option.empty[Cat]

optionCat1 === optionCat2
optionCat1 =!= optionCat2
```
</div>
