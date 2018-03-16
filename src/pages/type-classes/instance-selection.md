## インスタンスの選択を制御する

型クラスを扱う際は、インスタンスの選択の制御に関わる2つの論点について注意を払わなければならない:
 - ある型に対して定義されたインスタンスと、そのサブ型に対して定義されたインスタンスとの間の関係はど のようなものだろうか?

   例えば、`JsonWriter[Option[Int]]`を定義したとき、`Json.toJson(Some(1))`という式はこのインスタンスを選択することができるのだろうか?
   (`Some`は`Option`のサブ型であることを思い出してほしい)。

 - 利用できる複数の型クラスインスタンスがあるとき、どのインスタンスを選べばいいだろうか?

   例えば、`Person`に対する2つの`JsonWriter`を定義し、`Json.toJson(aPerson)`と書いたとき、どちらのインスタンスが選択されるのだろうか?

### 変性(variance) {#sec:variance}

型クラスを定義する際にその型パラメータに変位指定(variance annotation)を加えることで、型クラスの変性や、暗黙値の解決においてコンパイラがどのインスタンスを選択できるかということを指定できる。

Essential Scala の復習になるが、変性はサブ型に関係する。
型`A`の値が期待されている場所すべてにおいて型`B`の値を代わりに利用できるとき、`B`は`A`のサブ型であるという。

共変(covariance)・反変(contravariance)アノテーションは、型コンストラクタを扱う際に現れる。
例えば、`+`という記号によって、共変であることを示す:

```scala
trait F[+A] // "+"は「共変」を意味する
```

**共変**

共変性とは、`B`が`A`のサブ型であるときに`F[B]`が`F[A]`のサブ型であるという性質である。
これは、`List`や`Option`のようなコレクションを含む、多くの型をモデリングするのに役立つ:

```scala
trait List[+A]
trait Option[+A]
```

Scala コレクションは共変なので、ある型のコレクションを他の型のコレクションに代入できる。
例えば、`Circle`は`Shape`のサブ型なので、`List[Shape]`が期待されている場所ならばどこでも、`List[Circle]`を使うことができる:

```tut:book:silent
sealed trait Shape
case class Circle(radius: Double) extends Shape
```

```scala
val ciecles: List[Circle] = ???
val shapes: List[Shape] = circles
```

```tut:book:invisible
val circles: List[Circle] = null
val shapes: List[Shape] = circles
```

反変の場合はどうなるのだろうか?
以下のように`-`という記号をつけることで、反変な型コンストラクタとなる:

```scala
trait F[-A]
```

**反変**

混乱しやすいのだが、反変性とは`A`が`B`のサブ型であるときに`F[A]`が`F[B]`のサブ型であるという性質である。
これは、先程の`JsonWriter`型クラスのような、加工処理をモデリングするのに役立つ:

```tut:book:invisible
trait Json
```

```tut:book
trait JsonWriter[-A] {
  def write(value: A): Json
}
```

もう少し詳しく見ていこう。
変性とは、ある値を他の型として置き換えることができる能力に関するすべてである、ということを覚えておいてほしい。
型`Shape`の値と型`Circle`の値がそれぞれ1つずつあり、さらに`Shape`と`Circle`に対する`JsonWriter`もそれぞれ1つずつあるという状況を考える:

```scala
val shape: Shape = ???
val circle: Circle = ???

val shapeWriter: JsonWriter[Shape] = ???
val circleWriter: JsonWriter[Circle] = ???
```

```tut:book:invisible
val shape: Shape = null
val circle: Circle = null

val shapeWriter: JsonWriter[Shape] = null
val circleWriter: JsonWriter[Circle] = null
```

```tut:book:silent
def format[A](value: A, writer: JsonWriter[A]): Json =
  writer.write(value)
```

ここで、「どの値とwriterの組み合わせを`format`に渡すことができるだろうか?」という問について考えてみよう。
すべての`Circle`は`Shape`なので、`circle`はどちらのwriterとでも組み合わせることができる。
逆に、すべての`Shape`が`Circle`というわけではないので、`shape`を`circleWriter`と組み合わせることはできない。

この関係こそ、我々が反変性を用いてモデリングした関係なのだ。
`Circle`は`Shape`のサブ型なので、`JsonWriter[Shape]`は`JsonWriter[Circle]`のサブ型である。
これは、`JsonWriter[Circle]`を期待するすべての場所で`shapeWriter`を使えることを意味する。

**非変**

非変性は、もっとも説明しやすい状況である。
型コンストラクタの定義で`+`や`-`をつけなければ、非変となる:

```scala
trait F[A]
```

これは、`A`と`B`の関係にかかわらず、`F[A]`と`F[B]`が互いにもう一方のサブ型となることはない、ということを意味する。
Scala の型コンストラクタの意味論では、非変がデフォルトとなる。

コンパイラが暗黙の値を探す際は、求められている型 **またはそのサブ型** に一致する値を検索する。
したがって、変位指定を用いることで、型クラスインスタンスの選択肢を広げることができる。

よく陥りやすい、2つの問題がある。
次のような代数的データ型があるとしよう:

```tut:book:silent
sealed trait A
final case object B extends A
final case object C extends A
```

ここで次のような疑問が生じる:

 1. スーパー型に対して定義した型クラスのインスタンスが利用できるとき、それは選択されるだろうか?
    例えば、型`A`に対する型クラスのインスタンスを定義して、型`B`や`C`の値に適用することはできるのだろうか?

 2. サブ型に対する型クラスのインスタンスは、スーパー型に対するインスタンスよりも優先されるのだろうか?
    例えば、`A`と`B`に対する型クラスのインスタンスを定義し、型`B`の値があるとき、型`B`に対するインスタンスが`A`に対するインスタンスよりも優先的に選択されるのだろうか?

両方を一度に満たすことはできない。
下の表に示すように、コンパイラの振る舞いには3つの可能性がある:

-------------------------------------------------------------
型クラスの変性                           非変   共変   反変
---------------------------------------- ------ ------ ------
スーパー型のインスタンスが利用されるか?  ×      ×      ○

より特殊な型が優先されるか?              ×      ○     ×
-------------------------------------------------------------

完璧なシステムは存在しないのだ。
一般に、Cats では非変な型クラスが好まれる。
もし必要ならば、サブ型に対するより特殊化されたインスタンスを指定することができる。
例えば、型`Some[Int]`の値があっても、`Option`に対する型クラスのインスタンスが使われることはない。
`Some(1): Option[Int]`のように型を明示的に指定するか、[@sec:type-classes:comparing-options]節で見た`Option.apply`や`Option.empty`・`some`・`none`のような「スマートコンストラクタ」を利用することで、この問題を解決できる。
