## Semigroupal {#semigroupal}

[`cats.Semigroupal`][cats.Semigroupal]は、文脈を組み合わせることを可能にする型クラスである[^semigroupal-name]。
`F[A]`と`F[B]`という型を持つ2つのオブジェクトがあるとき、`Semigroupal[F]`を利用してそれらを`F[(A, B)]`という形に合成することができる。
Cats における定義は以下のようになっている:

```scala
trait Semigroupal[F[_]] {
  def product[A, B](fa: F[A], fb: F[B]): F[(A, B)]
}
```

本章のはじめに説明したように、引数の`fa`と`fb`は互いに独立している:
`product`に渡す前に、それらをどちらから計算してもかまわないということだ。
これは、引数の評価に厳密な順序を課す`flatMap`とは対照的である。
これにより、`Semigroupal`のインスタンスの定義は`Monad`の定義よりも自由度が高くなる。

[^semigroupal-name]: これは、Underscoreの「一貫した英文に組み入れるのが最も難しい関数プログラミング用語大賞2017」を受賞した用語でもある。

### 2つの文脈を結合する

`Semigroup`は値を結合することを可能にする一方で、`Semigroupal`は文脈を結合することを可能にする。
例として、いくつかの`Option`を結合してみよう:

```tut:book:silent
import cats.Semigroupal
import cats.instances.option._ // for Semigroupal
```

```tut:book
Semigroupal[Option].product(Some(123), Some("abc"))
```

両方の引数が`Some`のインスタンスならば、結果はその中にある値の組となる。
どちらかの引数が`None`に評価されるならば、全体の結果が`None`となる:

```tut:book
Semigroupal[Option].product(None, Some("abc"))
Semigroupal[Option].product(Some(123), None)
```

### 3つ以上の文脈を結合する

`Semigroupal`のコンパニオンオブジェクトには`product`の上で定義されたメソッドの集まりがある。
例えば、`tuple2`から`tuple22`までのメソッドは、異なる引数の数を持つ`product`の一般形である:

```tut:book:silent
import cats.instances.option._ // for Semigroupal
```

```tut:book
Semigroupal.tuple3(Option(1), Option(2), Option(3))
Semigroupal.tuple3(Option(1), Option(2), Option.empty[Int])
```

`map2`から`map22`までのメソッドは、ユーザが指定した関数を2つから22個までの文脈の中にある値に適用する:

```tut:book
Semigroupal.map3(Option(1), Option(2), Option(3))(_ + _ + _)

Semigroupal.map2(Option(1), Option.empty[Int])(_ + _)
```

`contramap2`から`contramap22`までのメソッドや、`imap2`から`imap22`までのメソッドもある。これらを利用するには、それぞれ`Contravariant`・`Invariant`のインスタンスが必要である。

## Apply 構文

Cats は、先ほど説明したメソッドたちの略記法である、便利な **Apply 構文** を提供している。
[`cats.syntax.apply`][cats.syntax.apply]からこの構文をインポートできる。
例えば、次のようになる:

```tut:book:silent
import cats.instances.option._ // for Semigroupal
import cats.syntax.apply._     // for tupled and mapN
```

`tupled`メソッドは`Option`のタプルに暗黙的に追加されるメソッドである。
これは`Option`に対する`Semigroupal`を利用して`Option`の中の値を綴じ合わせ、`Option`に入った1つのタプルを生成する:

```tut:book
(Option(123), Option("abc")).tupled
```

同じトリックを22個までの値を持つタプルに適用できる。
Cats は、それぞれの引数の数に対応する別々の`tupled`メソッドを定義している:

```tut:book
(Option(123), Option("abc"), Option(true)).tupled
```

`tupled`に加え、Cats の Apply 構文 は`mapN`と呼ばれる、暗黙の`Functor`と正しい数の引数を持つ関数をとって値を組み合わせるメソッドを提供する:

```tut:book:silent
case class Cat(name: String, born: Int, color: String)
```

```tut:book
(
  Option("Garfield"),
  Option(1978),
  Option("Orange & black")
).mapN(Cat.apply)
```

`mapN`の内部では、`Option`から値を取り出すために`Semigroupal`が、関数を値に適用するために`Functor`が用いられている。

嬉しいことに、この構文は型検査されている。
間違った数の、または間違った型の引数をとる関数を与えた場合、コンパイルエラーとなる:

```tut:book
val add: (Int, Int) => Int = (a, b) => a + b
```

```tut:book:fail
(Option(1), Option(2), Option(3)).mapN(add)
```

```tut:book:fail
(Option("cats"), Option(true)).mapN(add)
```

### 珍種の関手と Apply 構文

Apply 構文は、[Contravariant][#contravariant]または[Invariant][#invariant]を受け取る`contramapN`や`imapN`メソッドも持っている。
例えば、`Invariant`を用いて複数の`Monoid`を合成することができる。
これは次のようになる:

```tut:book:silent
import cats.Monoid
import cats.instances.boolean._ // for Monoid
import cats.instances.int._     // for Monoid
import cats.instances.list._    // for Monoid
import cats.instances.string._  // for Monoid
import cats.syntax.apply._      // for imapN

case class Cat(
  name: String,
  yearOfBirth: Int,
  favoriteFoods: List[String]
)

val tupleToCat: (String, Int, List[String]) => Cat =
  Cat.apply _

val catToTuple: Cat => (String, Int, List[String]) =
  cat => (cat.name, cat.yearOfBirth, cat.favoriteFoods)

implicit val catMonoid: Monoid[Cat] = (
  Monoid[String],
  Monoid[Int],
  Monoid[List[String]]
).imapN(tupleToCat)(catToTuple)
```

この`Monoid`は「空の」`Cat`を作ることと、複数の`Cat`を[@sec:monoids]章の構文を用いて組み合わせることを可能にする:

```tut:book:silent
import cats.syntax.semigroup._ // for |+|

val garfield   = Cat("Garfield", 1978, List("Lasagne"))
val heathcliff = Cat("Heathcliff", 1988, List("Junk Food"))
```

```tut:book
garfield |+| heathcliff
```
