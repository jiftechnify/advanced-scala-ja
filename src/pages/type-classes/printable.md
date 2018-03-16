## 演習: Printable ライブラリ

Scala は、どんな値でも`String`に変換できるように、`toString`メソッドを提供している。
しかし、このメソッドにはいくつかの欠点がある:
このメソッドは **すべての** 型に対して実装されており、多くの実装は使い物にならず、特定の型に対して特別な実装を選択することができない。

この問題に対処するために、`Printable`型クラスを定義しよう:

 1. 1つのメソッド`format`を持つ型クラス`Printable[A]`を定義せよ。
    `format`は、型`A`の値を受け取って`String`を返すようにすること。

 2. `String`と`Int`用のインスタンスを含む`PrintableInstances`オブジェクトを作成せよ。

 3. 2つのジェネリックなインターフェイスメソッドを持つ`Printable`オブジェクトを定義せよ。

    `format`は、型`A`の値と対応する`Printable`を取り、それを利用して`A`を`String`に変換するようにする。

    `print`は、`format`と同じ引数をとり、`Unit`を返すようにする。
    また、`println`を利用して型`A`の値を出力するようにすること。

<div class="solution">
これらのステップは型クラスの3つの構成要素を定義する。
まず、`Printable`--- **型クラス** それ自身を定義する:

```tut:book:silent
trait Printable[A] {
  def format(value: A): String
}
```

そして、いくつかの`Printable`のデフォルトインスタンスを定義し、それを`PrintableInstances`に入れる:

```tut:book:silent
object PrintableInstances {
  implicit val stringPrintable = new Printable[String] {
    def format(input: String) = input
  }

  implicit val intPrintable = new Printable[Int] {
    def format(input: Int) = input.toString
  }
}
```

最後に、`Printable` の **インターフェイス** オブジェクトを定義する:

```tut:book:silent
object Printable {
  def format[A](input: A)(implicit p: Printable[A]): String =
    p.format(input)

  def print[A](input: A)(implicit p: Printable[A]): Unit =
    println(format(input))
}
```
</div>

**ライブラリを利用する**

以上のコードは、多くの場所で応用できる汎用的な出力ライブラリを成す。
このライブラリを利用した「アプリケーション」を作成してみよう。

まず、誰もが知っているあのモフモフした動物を表現するデータ型を定義する:

```scala
final case class Cat(name: String, age: Int, color: String)
```

次に、以下のような形式で内容を返す、`Cat`のための`Printable`の実装を定義する:

```ruby
NAME is a AGE year-old COLOR cat.
```

最後に、この型クラスをコンソール、または小さなデモアプリケーションで利用する:
`Cat`のインスタンスを作り、それをコンソールに出力せよ:

```scala
// 猫を定義せよ:
val cat = Cat(/* ... */)

// 猫を出力せよ!
```

<div class="solution">
これは型クラスパターンの標準的な利用方法である。
まず、アプリケーションのためのカスタムデータ型をいくつか定義する:

```tut:book:silent
final case class Cat(name: String, age: Int, color: String)
```

次に、関心のある型のための型クラスインスタンスを定義する。
これらは`Cat`のコンパニオンオブジェクトの中に置いても、名前空間としてはたらく別のオブジェクトの中に置いてもよい:

```tut:book:silent
import PrintableInstances._

implicit val catPrintable = new Printable[Cat] {
  def format(cat: Cat) = {
    val name  = Printable.format(cat.name)
    val age   = Printable.format(cat.age)
    val color = Printable.format(cat.color)
    s"$name is a $age year-old $color cat."
  }
}
```

最後に、適切なインスタンスをスコープに含め、インターフェイスオブジェクト・インターフェイス構文を利用する。
インスタンスをコンパニオンオブジェクトに定義した場合は、Scala は自動的にインスタンスをスコープに含める。
そうでなければ、インスタンスにアクセスするために`import`を用いる:

```tut:book
val cat = Cat("Garfield", 38, "ginger and black")

Printable.print(cat)
```
</div>

**より良い構文**

より良い構文を提供する拡張メソッドを定義して、出力ライブラリをもっと使いやすいものにしよう。

 1. `PrintableSyntax`という名前のオブジェクトを作れ。

 2. `PrintableSyntax`の中に暗黙のクラス`implicit class PrintableOps[A]`を定義し、型`A`の値を包めるようにせよ。

 3. `PrintableOps`に次のメソッドを定義せよ:

     - `format`: 暗黙の`Printable[A]`型の値を受け取って、包まれた`A`型の値の`String`による表現を返すメソッド。

     - `print`: 暗黙の`Printable[A]`型の値をを受け取って`Unit`を返し、包まれた`A`型の値をコンソールに出力するメソッド。

 4. これらの拡張メソッドを利用して、前の演習問題で作成した`Cat`を出力せよ。

<div class="solution">
まず、拡張メソッドを含む`implicit class`を定義する:

```tut:book:silent
object PrintableSyntax {
  implicit class PrintableOps[A](value: A) {
    def format(implicit p: Printable[A]): String =
      Printable.format(value)

    def print(implicit p: Printable[A]): Unit =
      Printable.print(value)
  }
}
```

`PrintableOps`がスコープ内にあれば、Scala がその型に対応する`Printable`の暗黙インスタンスを見つけることができるような任意の型の値に対し、仮想的な`print`と`format`メソッドを呼び出すことができる:

```tut:book:silent
import PrintableSyntax._
```

```tut:book
Cat("Garfield", 38, "ginger and black").print
```

適切な型を持つ`Printable`のインスタンスが定義されていない場合、コンパイルエラーとなる:

```tut:book:silent
import java.util.Date
```

```tut:book:fail
new Date().print
```
</div>
