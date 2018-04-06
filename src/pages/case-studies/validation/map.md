## データの変換

要求のひとつに、データの変換を行う能力というものがある。
これにより、入力の解析のような付加的なシナリオをサポートできるようになる。
本節では、この追加の機能でチェックのライブラリを拡張していく。

`map`が出発点となるのは明らかだろう。
これを実装しようとすると、すぐに壁にぶつかることになる。
現在の`Check`の定義では、入力と出力の型が同じでなければならない:

```tut:book:silent
type Check[E, A] = A => Either[E, A]
```

チェックを変換するとき、結果にはどの型を割り当てればいいのだろうか?
それは`A`でも`B`でもない。
我々は袋小路に陥ってしまった:

```scala
def map(check: Check[E, A])(func: A => B): Check[E, ???]
```

`map`を実装するには、`Check`の定義を変更する必要がある。
具体的には、入力の型と出力の型を分離するための、新しい型変数が必要となる:

```tut:book:silent
type Check[E, A, B] = A => Either[E, B]
```

これで、チェックが`String`を`Int`として解析するといった操作を表現できるようになった。

```scala
val parseInt: Check[List[String], String, Int] =
  // ...
```

しかし、入力と出力の型を分けたことで新たな問題が発生する。
今までは、`Check`が成功時には常にその入力を返すという仮定を持っていた。
この仮定に基づき、`and`や`or`の成功時には左右のルールの出力を無視し、単にもともとの入力を返していた:

```scala
(this(a), that(a)) match {
  case And(left, right) =>
    (left(a), right(a))
      .mapN((result1, result2) => Right(a))

  // ...
}
```

新しい形式では、`Right(a)`を返すことはできない。なぜなら、この値の型は`Either[E, A]`であり、`Either[E, B]`ではないからだ。
`Right(result1)`か`Right(result2)`のどちらを返すかという選択を迫られることになる。
`or`メソッドに関しても同様である。
このことから、2つの結論を導くことができる:

- 忠実に従うべき法則を明示するように努める必要がある。
- このコードは、我々の`Check`の抽象化が間違っているということを示している。

### 条件(Predicates)

**条件** と **チェック** の概念を分離することで、先に進むことができる。
条件は *and* や *or* のような論理演算を用いて組み合わせることができ、チェックはデータを変換することができる。

これまで`Check`と呼んできたものを、これからは`Predicate`と呼ぶことにする。
`Predicate`に対して、「条件は成功時には常にその入力を返す」という性質を表現する、次のような **単位元の法則** を表明することができる。

> `Predicate[E, A]`型の条件`p`と
> `A`型の要素`a1`と`a2`について、
> `p(a1) == Success(a2)` ならば `a1 == a2`である。

この変更により、コードは次のようになる:

```tut:book:silent
import cats.Semigroup
import cats.data.Validated
import cats.syntax.semigroup._ // for |+|
import cats.syntax.apply._     // for mapN
import cats.data.Validated._   // for Valid and Invalid
```

```tut:book:silent
object wrapper {
  sealed trait Predicate[E, A] {
    def and(that: Predicate[E, A]): Predicate[E, A] =
      And(this, that)

    def or(that: Predicate[E, A]): Predicate[E, A] =
      Or(this, that)

    def apply(a: A)(implicit s: Semigroup[E]): Validated[E, A] =
      this match {
        case Pure(func) =>
          func(a)

        case And(left, right) =>
          (left(a), right(a)).mapN((_, _) => a)

        case Or(left, right) =>
          left(a) match {
            case Valid(a1)   => valid(a)
            case Invalid(e1) =>
              right(a) match {
                case Valid(a2)   => Valid(a)
                case Invalid(e2) => Invalid(e1 |+| e2)
              }
          }
      }
  }

  final case class And[E, A](
    left: Predicate[E, A],
    right: Predicate[E, A]) extends Predicate[E, A]

  final case class Or[E, A](
    left: Predicate[E, A],
    right: Predicate[E, A]) extends Predicate[E, A]

  final case class Pure[E, A](
    func: A => Validated[E, A]) extends Predicate[E, A]
}; import wrapper._
```

### チェック

`Check`を、`Predicate`から構築でき、さらにその入力を変換することもできるような構造を表現するのに使う。
次のようなインターフェイスを持つ`Check`を実装せよ:

```scala
sealed trait Check[E, A, B] {
  def apply(a: A): Validated[E, B] =
    ???

  def map[C](func: B => C): Check[E, A, C] =
    ???
}
```

<div class="solution">
`Predicate`と同様の方針に従うならば、次のようなコードになるはずだ:

```tut:book:silent
import cats.Semigroup
import cats.data.Validated
```

```tut:book:silent
object wrapper {
  sealed trait Check[E, A, B] {
    def apply(in: A)(implicit s: Semigroup[E]): Validated[E, B]

    def map[C](f: B => C): Check[E, A, C] =
      Map[E, A, B, C](this, f)
  }

  object Check {
    def apply[E, A](pred: Predicate[E, A]): Check[E, A, A] =
      Pure(pred)
  }

  final case class Map[E, A, B, C](
    check: Check[E, A, B],
    func: B => C) extends Check[E, A, C] {

    def apply(in: A)(implicit s: Semigroup[E]): Validated[E, C] =
      check(in).map(func)
  }

  final case class Pure[E, A](
    pred: Predicate[E, A]) extends Check[E, A, A] {

    def apply(in: A)(implicit s: Semigroup[E]): Validated[E, A] =
      pred(in)
  }
}; import wrapper._
```
</div>

`flatMap`はどうなるだろうか?
ここでは、そのセマンティクスは明らかではない。
そのメソッドを実装するのは十分簡単だが、それが何を意味するのか、または`apply`をどう実装すべきかについてはあまり明白ではない。
`flatMap`の一般的な形式は図[@fig:validation:generic-flatmap]に示すとおりだ。

![flatMap の型チャート](src/pages/monads/generic-flatmap.pdf+svg){#fig:validation:generic-flatmap}

我々のコードの`Check`と、この図の中の`F`をどのように対応させればよいだろうか?
`Check`は **3つ** の型変数を持つ一方、`F`は1つしか持たない。

これらの型を単一化するには、2つの型パラメータを固定する必要がある。
慣用的な選択は、エラーの型`E`と入力の型`A`を固定するというものである。
これは図[@fig:validation:check-flatmap]に示すような関係をもたらす。
言い換えれば、`FlatMap`の適用のセマンティクスとは:

- `A`型の入力が与えられると、`F[B]`に変換する

- `Check[E, A, C]`を選択するために、`B`型の出力を利用する

- もともとの型である`A`型の入力をとり、選択されたチェックにそれを適用し、最終的な`F[C]`型の結果を生成する

![Check に適用された flatMap の型チャート](src/pages/case-studies/validation/flatmap.pdf+svg){#fig:validation:check-flatmap}

これはかなり奇妙なメソッドだ。
これを実装することはできる。しかし、利用できる場面を見つけるのは難しい。
とにかく、`Check`の`flatMap`を実装しよう。その後、一般的により便利なメソッドを見ていく。

<div class="solution">
ただひとつの問題点を除けば、前と同じ実装方針を用いることができる。問題は、`Validated`が`flatMap`メソッドを持たないということだ。
`flatMap`を実装するには、一瞬だけ`Either`に切り替え、あとで`Validated`に戻す必要がある。
`Validated`にある`withEither`メソッドがちょうどこれを行う。
`apply`を実装するには、あとは型に従うだけでよい。

```tut:book:silent
import cats.Semigroup
import cats.data.Validated
```

```tut:book:silent
object wrapper {
  sealed trait Check[E, A, B] {
    def apply(in: A)(implicit s: Semigroup[E]): Validated[E, B]

    def flatMap[C](f: B => Check[E, A, C]) =
      FlatMap[E, A, B, C](this, f)

    // 他のメソッド...
  }

  final case class FlatMap[E, A, B, C](
    check: Check[E, A, B],
    func: B => Check[E, A, C]) extends Check[E, A, C] {

    def apply(a: A)(implicit s: Semigroup[E]): Validated[E, C] =
      check(a).withEither(_.flatMap(b => func(b)(a).toEither))
  }

  // 他のデータ型...
}; import wrapper._
```
</div>

2つの`Check`を繋げる、もっと有用なコンビネータを書くことができる。
1つ目のチェックの出力が2つ目のチェックの入力に接続される。
これは、`andThen`を用いた関数合成に似ている:

```scala
val f: A => B = ???
val g: B => C = ???
val h: A => C = f andThen g
```

`Check`は基本的には`A => Validated[E, B]`型の関数なので、似たような`andThen`メソッドを定義できる:

```scala
trait Check[E, A, B] {
  def andThen[C](that: Check[E, B, C]): Check[E, A, C]
}
```

`andThen`を実装してみよう!

<div class="solution">
`andThen`と、それに対応する`AndThen`クラスの最小限の定義は以下のようになる:

```tut:book:silent
object wrapper {
  sealed trait Check[E, A, B] {
    import Check._

    def apply(in: A)(implicit s: Semigroup[E]): Validated[E, B]

    def andThen[C](that: Check[E, B, C]): Check[E, A, C] =
      AndThen[E, A, B, C](this, that)
  }

  final case class AndThen[E, A, B, C](
    check1: Check[E, A, B],
    check2: Check[E, B, C]) extends Check[E, A, C] {

    def apply(a: A)(implicit s: Semigroup[E]): Validated[E, C] =
      check1(a).withEither(_.flatMap(b => check2(b).toEither))
  }
}; import wrapper._
```
</div>

### 復習

今、我々には`Predicate`と`Check`という2つの代数的データ型と、関連するケースクラスによって実装された多くのコンビネータがある。
それぞれの ADT の完全な定義を見たければ、下の解答を参照してほしい。

<div class="solution">
これが、コードの整理や再パッケージ化を行ったあとの、最終的な実装である:

```tut:book:silent:reset
import cats.Semigroup
import cats.data.Validated
import cats.data.Validated._   // for Valid and Invalid
import cats.syntax.semigroup._ // for |+|
import cats.syntax.apply._     // for mapN
import cats.syntax.validated._ // for valid and invalid
```

`and`と`or`メソッド、さらに関数から`Predicate`を生成する`Predicate.apply`メソッドを含む、`Predicate`の完全な実装を以下に示す:

```tut:book:silent
object wrapper {
  sealed trait Predicate[E, A] {
    import Predicate._

    def and(that: Predicate[E, A]): Predicate[E, A] =
      And(this, that)

    def or(that: Predicate[E, A]): Predicate[E, A] =
      Or(this, that)

    def apply(a: A)(implicit s: Semigroup[E]): Validated[E, A] =
      this match {
        case Pure(func) =>
          func(a)

        case And(left, right) =>
          (left(a), right(a)).mapN((_, _) => a)

        case Or(left, right) =>
          left(a) match {
            case Valid(a1)   => Valid(a)
            case Invalid(e1) =>
              right(a) match {
                case Valid(a2)   => Valid(a)
                case Invalid(e2) => Invalid(e1 |+| e2)
              }
          }
      }
  }

  object Predicate {
    final case class And[E, A](
      left: Predicate[E, A],
      right: Predicate[E, A]) extends Predicate[E, A]

    final case class Or[E, A](
      left: Predicate[E, A],
      right: Predicate[E, A]) extends Predicate[E, A]

    final case class Pure[E, A](
      func: A => Validated[E, A]) extends Predicate[E, A]

    def apply[E, A](f: A => Validated[E, A]): Predicate[E, A] =
      Pure(f)

    def lift[E, A](err: E, fn: A => Boolean): Predicate[E, A] =
      Pure(a => if(fn(a)) a.valid else err.invalid)
  }
}; import wrapper._
```

以下に`Check`の完全な実装を示す。
Scala のパターンマッチングに存在する[型推論のバグ][link-si-6680]に対処するため、`apply`の実装を継承を用いるものに変更した:

```tut:book:silent
object wrapper {
  sealed trait Check[E, A, B] {
    import Check._

    def apply(in: A)(implicit s: Semigroup[E]): Validated[E, B]

    def map[C](f: B => C): Check[E, A, C] =
      Map[E, A, B, C](this, f)

    def flatMap[C](f: B => Check[E, A, C]) =
      FlatMap[E, A, B, C](this, f)

    def andThen[C](next: Check[E, B, C]): Check[E, A, C] =
      AndThen[E, A, B, C](this, next)
  }

  object Check {
    final case class Map[E, A, B, C](
      check: Check[E, A, B],
      func: B => C) extends Check[E, A, C] {

      def apply(a: A)
          (implicit s: Semigroup[E]): Validated[E, C] =
        check(a) map func
    }

    final case class FlatMap[E, A, B, C](
      check: Check[E, A, B],
      func: B => Check[E, A, C]) extends Check[E, A, C] {

      def apply(a: A)
          (implicit s: Semigroup[E]): Validated[E, C] =
        check(a).withEither(_.flatMap(b => func(b)(a).toEither))
    }

    final case class AndThen[E, A, B, C](
      check: Check[E, A, B],
      next: Check[E, B, C]) extends Check[E, A, C] {

      def apply(a: A)
          (implicit s: Semigroup[E]): Validated[E, C] =
        check(a).withEither(_.flatMap(b => next(b).toEither))
    }

    final case class Pure[E, A, B](
      func: A => Validated[E, B]) extends Check[E, A, B] {

      def apply(a: A)
          (implicit s: Semigroup[E]): Validated[E, B] =
        func(a)
    }

    final case class PurePredicate[E, A](
      pred: Predicate[E, A]) extends Check[E, A, A] {

      def apply(a: A)
          (implicit s: Semigroup[E]): Validated[E, A] =
        pred(a)
    }

    def apply[E, A](pred: Predicate[E, A]): Check[E, A, A] =
      PurePredicate(pred)

    def apply[E, A, B]
        (func: A => Validated[E, B]): Check[E, A, B] =
      Pure(func)
  }
}; import wrapper._
```
</div>

最初に成し遂げようとしていたことのほとんどを行えるような、`Check`と`Predicate`の完全な実装ができた。
しかし、まだ終わりではない。
`Predicate`や`Check`の中に抽象化できる構造があることに気づいたかもしれない:
`Predicate`はモノイドであり、`Check`はモナドである。
さらに、`Check`の実装中、その実装がほとんど何もしていないと感じたかもしれない---するべきことは、内部の`Predicate`や`Validated`のメソッドを呼び出すことだけなのだ。

このライブラリをもっときれいにする方法はたくさんあるが、
ここでこのライブラリが実際に動作しすることを確認するいくつかの例を実装してみよう。改良を行うのはそれからにしよう。

導入で挙げた例のようなチェックを実装せよ:

- ユーザ名は少なくとも4つの文字を含み、すべての文字は英数字でなければならない

- Eメールアドレスは1つの`@`記号を含まなければならない。
  `@`で分割したとき、その左側は空でなく、右側は少なくとも3文字のからなり、ドットを含まなければならない

以下の条件を自由に用いてよい:

```tut:book:silent
import cats.data.{NonEmptyList, Validated}
```

```tut:book:silent
object wrapper {
  type Errors = NonEmptyList[String]

  def error(s: String): NonEmptyList[String] =
    NonEmptyList(s, Nil)

  def longerThan(n: Int): Predicate[Errors, String] =
    Predicate.lift(
      error(s"Must be longer than $n characters"),
      str => str.size > n)

  val alphanumeric: Predicate[Errors, String] =
    Predicate.lift(
      error(s"Must be all alphanumeric characters"),
      str => str.forall(_.isLetterOrDigit))

  def contains(char: Char): Predicate[Errors, String] =
    Predicate.lift(
      error(s"Must contain the character $char"),
      str => str.contains(char))

  def containsOnce(char: Char): Predicate[Errors, String] =
    Predicate.lift(
      error(s"Must contain the character $char only once"),
      str => str.filter(c => c == char).size == 1)
}; import wrapper._
```

<div class="solution">
参考のための解答を以下に示す。
実装のためには、思ったよりも熟慮が必要となる。
`Predicate`がその入力を変換できないという制約を理解できるまでは、適切な箇所で`Check`と`Predicate`を切り替える作業は当てずっぽうにならざるを得ないだろう。
この制約を頭に入れれば、かなり順調に進めるようになるはずだ。
次の節で、このライブラリがより使いやすくなるよう、いくつかの変更を行う。

```tut:book:silent
import cats.data.{NonEmptyList, Validated}
import cats.syntax.apply._     // for mapN
import cats.syntax.validated._ // for valid and invalid
```

これが`checkUsername`の実装だ:

```tut:book:silent
// ユーザ名は少なくとも4つの文字を含み、
// すべての文字は英数字でなければならない

val checkUsername: Check[Errors, String, String] =
  Check(longerThan(3) and alphanumeric)
```

そしてこれが、より小さな構成要素から構築された、`checkEmail`の実装である:

```tut:book:silent
// Eメールアドレスはただひとつの`@`記号を含む。
// `@`で文字列を分割したとき、
// その左側の文字列は空であってはならず、
// その右側の文字列は少なくとも3文字以上で、ドットを含まなければならない。

val splitEmail: Check[Errors, String, (String, String)] =
  Check(_.split('@') match {
    case Array(name, domain) =>
      (name, domain).validNel[String]

    case other =>
      "Must contain a single @ character".
        invalidNel[(String, String)]
  })

val checkLeft: Check[Errors, String, String] =
  Check(longerThan(0))

val checkRight: Check[Errors, String, String] =
  Check(longerThan(3) and contains('.'))

val joinEmail: Check[Errors, (String, String), String] =
  Check { case (l, r) =>
    (checkLeft(l), checkRight(r)).mapN(_ + "@" + _)
  }

val checkEmail: Check[Errors, String, String] =
  splitEmail andThen joinEmail
```

最後に、`checkUsername`と`checkEmail`に基づく、`User`に対するチェックは次のようになる:

```tut:book:silent
final case class User(username: String, email: String)

def createUser(
      username: String,
      email: String): Validated[Errors, User] =
  (checkUsername(username), checkEmail(email)).mapN(User)
```

いくつかの仮のユーザを生成して、正しく動作するか確認してみよう:

```tut:book
createUser("Noel", "noel@underscore.io")
createUser("", "dave@underscore@io")
```

この例の大きな欠点は、エラーが **どこに** あるのかを教えてくれないということだ。
注意深くエラーメッセージの操作を行うか、メッセージと同時にエラーの箇所を記録するようにライブラリを変更することで、この欠点を克服できる。
エラーの箇所を記録するのは、この事例研究の範囲を超えるので、これは読者への課題とする。
</div>
