## Cats に出会う

前節では、Scala で型クラスを実装する方法を見た。
本節では、Cats において型クラスがどのように実装されているのかを見ていく。

Cats は、使いたい型クラス、型クラスのインスタンス、型クラスのインターフェイスを開発者が選べるよう、モジュール化された構造に沿って書かれている。
まずは、[`cats.Show`][cats.Show]を例をとして見ていこう。

Cats における`Show`は、我々が前節で定義した `Printable` 型クラスと同じものである。
`toString`を使わずに、開発者が読みやすいコンソール出力を生成する機構を提供している。
`Show`の、詳細を省いた定義は以下の通りである:

```scala
package cats

trait Show[A] {
  def show(value: A): String
}
```

### 型クラスのインポート

Cats の型クラスは[`cats`][cats.package]パッケージに定義されている。
このパッケージから`Show`を直接インポートできる:

```tut:book:silent
import cats.Show
```

Cats における各型クラスに対応するコンパニオンオブジェクトは、指定された任意の型に対するインスタンスを探し出す`apply`メソッドを持つ:

```tut:book:fail
val showInt = Show.apply[Int]
```

おっと、うまくいっていないようだ!
`apply`メソッドが個々のインスタンスを見つけるには **暗黙の値** が必要なので、何らかのインスタンスをスコープ内に持ってこなければならない。

### 組み込みインスタンスのインポート {#importing-default-instances}

[`cats.instances`][cats.instances]パッケージには、様々な型に対する組み込みの型クラスインスタンスが含まれている。
これらをインポートする方法を以下の表にまとめた。
それぞれが、Cats にあるすべての型クラスの特定のパラメータ型に対するインスタンスを含んでいる。

- [`cats.instances.int`][cats.instances.int]は、`Int`に対するインスタンスを含む
- [`cats.instances.string`][cats.instances.string]は、`String`に対するインスタンスを含む
- [`cats.instances.list`][cats.instances.list]は`List`に対するインスタンスを含む
- [`cats.instances.option`][cats.instances.option]は`Option`に対するインスタンスを含む
- [`cats.instances.all`][cats.instances.all]はCats が提供するすべてのインスタンスを含む

利用できるすべてのインポートを知りたければ、[`cats.instances`][cats.instances]を参照するとよい。

それでは、`Int`と`String`に対する`Show`のインスタンスをインポートしてみよう:

```tut:book:silent
import cats.instances.int._    // for Show
import cats.instances.string._ // for Show

val showInt:    Show[Int]    = Show.apply[Int]
val showString: Show[String] = Show.apply[String]
```

良くなった! これで、`Show`の2つのインスタンスにアクセスして、`Int`や`String`を出力するのに利用できるようになった:

```tut:book
val intAsString: String =
  showInt.show(123)

val stringAsString: String =
  showString.show("abc")
```

### インターフェイス構文のインポート

[`cats.syntax.show`][cats.syntax.show]から **インターフェイス構文** をインポートすれば、`Show`をもっと楽に利用できるようになる。
これはスコープ内に`Show`のインスタンスが存在するすべての型に対し、`show`という拡張メソッドを追加する:

```tut:book:silent
import cats.syntax.show._ // for Show
```

```tut:book
val shownInt = 123.show

val shownString = "abc".show
```

Cats はそれぞれの型クラスに対して別々の構文インポートを提供している。
これについては、後の章や節で出会ったときに解説する。

### すべてをインポート!

本書では、それぞれの例で本当に必要なインスタンスや構文を示すために、限定的なインポートを利用する。
しかし多くの場合、この方法では時間がかかってしまうだろう。
インポートを簡潔にするために、次のようなショートカットのいずれかを利用してもかまわない:

- `import cats._`は、Cats のすべての型クラスを一度にインポートする

- `import cats.instances.all._` は、標準ライブラリに対するすべての型クラスインスタンスを一度にインポートする

- `import cats.syntax.all_`は、すべてのインターフェイス構文を一度にインポートする

- `import cats.implicits._`は、標準ライブラリに対するすべての型クラス **および** 全ての構文を一度にインポートする

多くの開発者は、はじめにファイルの先頭に次のようなインポートを書き、名前の衝突や曖昧なインポートの問題が起きた際に、より限定的なインポートに書き直す:

```tut:book:silent
import cats._
import cats.implicits._
```

### 独自の型クラスインスタンスを定義する {#defining-custom-instances}

`Show`のインスタンスを定義するには、所望の型に対応するトレイトを実装するだけでいい:

```tut:book:silent
import java.util.Date

implicit val dateShow: Show[Date] =
  new Show[Date] {
    def show(date: Date): String =
      s"${date.getTime}ms since the epoch."
  }
```

しかし、Cats はこの過程を簡潔にするために、いくつかの便利なメソッドを提供している。
`Show`のコンパニオンオブジェクトには、自分で作った型に対するインスタンスを定義するのに使える2つの構築メソッドが用意されている:

```scala
object Show {
  // 関数を`Show`のインスタンスに変換する
  def show[A](f: A => String): Show[A] =
    ???

  // `toString`メソッドから`Show`のインスタンスを作る
  def fromToString[A]: Show[A] =
    ???
}
```

これらのメソッドを使えば、何もないところからインスタンスを定義するよりも簡単に、素早くインスタンスを構築できる:

```tut:book:silent
implicit val dateShow: Show[Date] =
  Show.show(date => s"${date.getTime}ms since the epoch.")
```

見ての通り、構築メソッドを使ったコードは、使っていないコードに比べて簡潔である。
Cats の多くの型クラスは、以上のようなインスタンスを構築するためのヘルパーメソッドを提供している。これを用いれば、ゼロから、または他の型に対する既存のインスタンスを変換することで、インスタンスを構築できる。

### 演習: キャット・ショー

`Printable`の代わりに`Show`を用いて、前節の`Cat`アプリケーションを再実装せよ。

<div class="solution">
まず、Cats から必要なすべてのもの(`Show`型クラス、`Int`と`String`に対するインスタンス、そしてインターフェイス構文)をインポートしよう:

```tut:book:silent
import cats.Show
import cats.instances.int._    // for Show
import cats.instances.string._ // for Show
import cats.syntax.show._      // for Show
```

`Cat`の定義はそのままでよい:

```tut:book:silent
final case class Cat(name: String, age: Int, color: String)
```

コンパニオンオブジェクトの`Printable`を、前節で見た定義ヘルパーの1つを利用した`Show`のインスタンスに書き換える:

```tut:book:silent
implicit val catShow = Show.show[Cat] { cat =>
  val name  = cat.name.show
  val age   = cat.age.show
  val color = cat.color.show
  s"$name is a $age year-old $color cat."
}
```

最後に、`Show`のインターフェイス構文を利用して`Cat`のインスタンスを出力する:

```tut:book
println(Cat("Garfield", 38, "ginger and black").show)
```
</div>
