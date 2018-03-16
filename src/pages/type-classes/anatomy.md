## 型クラスを解剖する

型クラスパターンには3つの重要な構成要素がある:
**型クラス** それ自身、
特定の型に対する **インスタンス**、
そして、ユーザに公開する **インターフェイス** メソッドだ。

### 型クラス

**型クラス** とは、実装しようとしている何らかの機能を表現するインターフェイス、またはAPIである。
Cats では、型クラスは少なくとも1つの型パラメータを持つトレイトによって表現されている。
例えば、汎用的な「JSONにシリアライズできる」という振る舞いを次のように表現できる。

```tut:book:silent
// JSON 抽象構文木の非常に簡素な定義
sealed trait Json
final case class JsObject(get: Map[String, Json]) extends Json
final case class JsString(get: String) extends Json
final case class JsNumber(get: Double) extends Json
case object JsNull extends Json

// 「JSONにシリアライズできる」という振る舞いをトレイトとして表す
trait JsonWriter[A] {
  def write(value: A): Json
}
```

この例において、`JsonWriter` は型クラスであり、`Json` とそのサブ型はサポートコードとして与えられている。

### 型クラスのインスタンス

型クラスの **インスタンス** とは、関心のある型に対する型クラスの実装である。この「型」には、Scala 標準ライブラリの型と、独自のドメインモデルにある型の両方が含まれる。

Scala では、型クラスの具体的な実装を作成し、それに `implicit` というキーワードによって印をつけることで型クラスのインスタンスを定義する:

```tut:book:silent
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

  // 続く...
}
```

### 型クラスのインターフェイス

型クラスの **インターフェイス** は、ユーザに公開する全ての機能を指す。
インターフェイスは、型クラスのインスタンスを暗黙のパラメータとして受け取る、ジェネリックなメソッドとして定義される。

インターフェイスを定義するのに使われる2つの一般的な方法がある:
**インターフェイスオブジェクト** と **インターフェイス構文** だ。

**インターフェイスオブジェクト**

インターフェイスを定義するための最も単純な方法は、シングルトンオブジェクトの中にメソッドを配置するという方法だ:

```tut:book:silent
object Json {
  def toJson[A](value: A)(implicit w: JsonWriter[A]): Json =
    w.write(value)
}
```

このオブジェクトを利用するには、関心のある型クラスのインスタンスをインポートし、適切なメソッドを呼び出す:

```tut:book:silent
import JsonWriterInstances._
```

```tut:book
Json.toJson(Person("Dave", "dave@example.com"))
```

コンパイラは、暗黙のパラメータが与えられていない`toJson` メソッドの呼び出しを検出すると、適切な型を持つ型クラスのインスタンスを探してメソッド呼び出しに挿入する。

```tut:book:silent
Json.toJson(Person("Dave", "dave@example.com"))(personWriter)
```

**インターフェイス構文**

インターフェイスメソッドによって既存の型を拡張するために、 **拡張メソッド** を利用することもできる[^pimping]。
Cats では、これを型クラスの **構文(syntax)** と呼ぶ:

[^pimping]: 拡張メソッドは「型の強化(type enrichment)」や「改造(pimping)」と呼ばれる場合もあるが、これらの用語は今では死語となっている。

```tut:book:silent
object JsonSyntax {
  implicit class JsonWriterOps[A](value: A) {
    def toJson(implicit w: JsonWriter[A]): Json =
      w.write(value)
  }
}
```

これを必要な型のインスタンスと一緒にインポートすることで、インターフェイス構文を利用できるようになる:

```tut:book:silent
import JsonWriterInstances._
import JsonSyntax._
```

```tut:book:silent
Person("Dave", "dave@example.com").toJson
```

この場合も、コンパイラは暗黙のパラメータに与える値の候補を探し、補完してくれる:

```tut:book
Person("Dave", "dave@example.com").toJson(personWriter)
```

***implicitly* メソッド**

Scala 標準ライブラリには `implicitly` と呼ばれるジェネリックな型クラスインターフェイスが用意されている。
その定義はとてもシンプルだ:

```tut:book:silent
def implicitly[A](implicit value: A): A =
  value
```

`implicitly` を利用すれば、暗黙のスコープからどんな値でも召喚することができる。
所望の型を指定すれば、残った仕事は`implicitly`が全てやってくれる:

```scala
import JsonWriterInstances._

implicitly[JsonWriter[String]]
```

Cats に含まれる多くの型クラスは、他にもインスタンスを召喚するための方法を提供しているが、それでも`implicitly`はデバッグにおいて良い代替品となる。
コードの任意の場所に`implicitly`の呼び出しを挿入すれば、コンパイラが型クラスのインスタンスを見つけられることや、曖昧な暗黙の値によるエラーがないことを確認できる。
