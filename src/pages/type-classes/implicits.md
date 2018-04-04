## Implicitを味方につける

```tut:book:invisible
// Forward definitions

sealed trait Json
final case class JsObject(get: Map[String, Json]) extends Json
final case class JsString(get: String) extends Json
final case class JsNumber(get: Double) extends Json
case object JsNull extends Json

trait JsonWriter[A] {
  def write(value: A): Json
}

final case class Person(name: String, email: String)

object JsonWriterInstances {
  implicit val stringWriter: JsonWriter[String] =
    new JsonWriter[String] {
      def write(value: String): Json =
        JsString(value)
    }

  implicit val personWriter: JsonWriter[Person] =
    new JsonWriter[Person] {
      def write(value: Person): Json =
        JsObject(Map(
          "name" -> JsString(value.name),
          "email" -> JsString(value.email)
        ))
    }

  // etc...
}

import JsonWriterInstances._

object Json {
  def toJson[A](value: A)(implicit w: JsonWriter[A]): Json =
    w.write(value)
}
```

Scala で型クラスを扱うということは、暗黙の値や暗黙の引数を扱うことに等しい。
これを効果的に行うには、いくつかのルールを知っておかなくてはならない。

### 暗黙の値をパッケージ化する

Scala 言語には奇妙な「癖」があり、`implicit`がつく定義は何であろうともトップレベルに置くことはできない。それらはオブジェクトまたはトレイトの中に配置しなければならない。
先程の例では、型クラスのインスタンスを`JsonWriterInstances`というオブジェクトの中に収めた。
同様にして、型クラスのインスタンスを`JsonWriter`のコンパニオンオブジェクトの中に配置することもできる。
コンパニオンオブジェクトの中にインスタンスを置くことは、Scala では特別な意味を持つ。これは、コンパニオンオブジェクトが **暗黙のスコープ** と呼ばれる役割を果たすためである。

### 暗黙のスコープ

先程見たように、コンパイラは型に基づいて候補となる型クラスのインスタンスを探す。
例えば、以下の式を書くとコンパイラは`JsonWriter[String]`の型を持つインスタンスを探す:

```tut:book:silent
Json.toJson("A string!")
```

コンパイラは呼び出し地点における **暗黙のスコープ** の中から候補となる型クラスのインスタンスを探し出す。暗黙のスコープは、大雑把にいうと以下の要素からなる:

- ローカルの、または継承された定義
- インポートされた定義
- 型クラス、または型パラメータとして指定された型(この例では`JsonWriter`または`String`)のコンパニオンオブジェクトの中にある定義

暗黙のスコープには、`implicit`キーワードがついた定義のみが含まれる。
さらに、もしコンパイラが候補となる複数の定義を見つけた場合、**曖昧な暗黙の値(ambiguous implicit values)** エラーとともにコンパイルに失敗する:

```scala
implicit val writer1: JsonWriter[String] =
  JsonWriterInstances.stringWriter

implicit val writer2: JsonWriter[String] =
  JsonWriterInstances.stringWriter

Json.toJson("A string")
// <console>:23: error: ambiguous implicit values:
//  both value stringWriter in object JsonWriterInstances of type => JsonWriter[String]
//  and value writer1 of type => JsonWriter[String]
//  match expected type JsonWriter[String]
//          Json.toJson("A string")
//                     ^
```

暗黙値を解決するための正確な規則はもっと複雑だが、本書においてこの複雑な部分が問題となることはほとんどない[^implicit-search]。
目的を果たすために、大きく分けて4つの方法で型クラスのインスタンスをパッケージ化することができる:

1. `JsonWriterInstances`のようなオブジェクトの中に配置する
2. トレイトの中に配置する
3. 型クラスのコンパニオンオブジェクトの中に配置する
4. 型パラメータとして与える型のコンパニオンオブジェクトの中に配置する

1つ目の方法では、オブジェクトをインポートすることでインスタンスを持ってくる。
2つ目の方法では、トレイトを継承することでインスタンスをスコープに入れる。
3つ目および4つ目の方法では、利用しようとするかどうかにかかわらず、インスタンスは **常に** 暗黙のスコープの中にある。

[^implicit-search]: Scala における、より正確な暗黙値の解決規則に興味があるならば、まず[暗黙のスコープに関する Stack Overflow の投稿][link-so-implicit-scope]や[暗黙値の優先順位に関するブログ記事][link-implicit-priority]を読むといいだろう。

### 再帰的な暗黙値の解決 {#sec:type-classes:recursive-implicits}

型クラスと暗黙の値の真の力は、コンパイラが持つ、候補のインスタンスを探す際に暗黙の定義を **組み合わせる** ことができるという能力によって引き出される。

先程、すべての型クラスのインスタンスは`impicit val`であるということを仄めかしたが、それは簡単のためである。
実際には、2つの方法でインスタンスを定義することができる:

1. 必要とされている型の`implicit val`として具体的なインスタンスを定義する[^implicit-objects]
2. 他の型クラスのインスタンスから新たなクラスを構築する`implicit`メソッドを定義する

[^implicit-objects]: `implicit object` も同様に扱う。

なぜ他のインスタンスからインスタンスを構築する必要があるのだろうか?
動機づけのための例として、`Option`のための`JsonWriter`を定義することを考えよう。
関心のあるすべての型`A`について`JsonWriter[Option[A]]`が欲しい。
すべての`implicit val`を定義したライブラリを作るという総当たり的な方法を試すことはできる:

```scala
implicit val optionIntWriter: JsonWriter[Option[Int]] =
  ???

implicit val optionPersonWriter: JsonWriter[Option[Person]] =
  ???

// 以下同様...
```

しかし、この方法は明らかにスケールしない。
結局、それぞれの型`A`に対して、`A`と、`Option[A]`に対応する2つの`implicit val`を書く必要がある。

幸い、`Option[A]`を扱うコードを、`A`に対するインスタンスを基にする共通のコンストラクタとして抽象化できる:

- もしオプション値が`Some(aValue)`ならば、`A`型のwriterを使って`aValue`を出力する

- もしオプション値が`None`ならば、`null`を出力する

`implicit def`の形でこれを書くと以下のようになる:

```tut:book:silent
implicit def optionWriter[A]
    (implicit writer: JsonWriter[A]): JsonWriter[Option[A]] =
  new JsonWriter[Option[A]] {
    def write(option: Option[A]): Json =
      option match {
        case Some(aValue) => writer.write(aValue)
        case None         => JsNull
      }
  }
```

このメソッドは、`A`という型に特有の機能を満たすために暗黙の引数を利用し、`Option[A]`のための`JsonWriter`を **構築** する。
コンパイラが以下のような式を見つけたとする:

```tut:book:silent
Json.toJson(Option("A string"))
```

すると、コンパイラは暗黙の`JsonWriter[Option[String]]`型の値を探し、`JsonWriter[Option[A]]`型の値を返す暗黙のメソッドを見つける:

```tut:book:silent
Json.toJson(Option("A string"))(optionWriter[String])
```

そして、`optionWriter`の引数として利用する`JsonWriter[String]`の値を再帰的に探し出す:

```tut:book:silent
Json.toJson(Option("A string"))(optionWriter(stringWriter))
```

このようにして、暗黙値の解決は暗黙の定義のすべての可能な組み合わせを探し、全体として正しい型を持つ型クラスのインスタンスを召喚するための組み合わせを見つけ出す。

<div class="callout callout-warning">
**暗黙の型変換**

`implicit def`を利用して型クラスインスタンスのコンストラクタを作成する際は、必ずメソッドの仮引数に`implicit`をつけるよう注意すること。
このキーワードがないと、暗黙値の解決においてコンパイラがその引数を埋めることができなくなってしまう。

`implicit`でない引数を持った`implicit`メソッドは、 **暗黙の型変換** と呼ばれる Scala における別のプログラミングパターンである。
これは前節におけるインターフェイス構文とも異なる。インターフェイス構文では、`JsonWriter`は拡張メソッドを持った暗黙のクラスとして定義する。

暗黙の型変換は古いプログラミングパターンであり、モダンな Scala コードの中では顰蹙を買うだろう。
幸い、これを書くとコンパイラが注意を促してくれる。
暗黙の型変換を有効にするには、`scala.language.implicitConversions`をインポートする必要がある:

```tut:book:fail
implicit def optionWriter[A]
    (writer: JsonWriter[A]): JsonWriter[Option[A]] =
  ???
```
</div>
