## クライスリ

`Check`の実装を整理して、この事例研究の締めくくりとする。
我々の方針に対する正当な批判として、少しのことをするのにたくさんのコードを書かなければならないというものがある。
`Predicate`は実質`A => Validated[E, A]`型の関数で、`Check`は基本的にはこれらの関数を合成できるようにするラッパーでしかない。

`A => Validated[E, B]`を`A => F[B]`という形に抽象化することができる。これが、モナドの`flatMap`メソッドに渡す関数の型だということに気づいたかもしれない。
次のような一連の操作があると想像してみよう:

- (例えば、`pure`を用いて)ある値をモナドに持ち上げる。
  これは`A => F[A]`という型を持つ関数である。

- モナドの上で、`flatMap`を利用していくつかの変換を逐次的に行う。

これは、図[@fig:validation:kleisli]のように表すことができる。
この例を、モナドの API を利用して次のように書き下すこともできる:

```scala
val atoB: A => F[B] = ???
val btoC: B => F[C] = ???

def example[A, C](a: A): F[C] =
  aToB(a).flatMap(bToc)
```

![モナド的変換の連鎖](src/pages/case-studies/validation/kleisli.pdf+svg){#fig:validation:kleisli}

抽象的にいえば、`Check`は`A => F[B]`型の関数を合成することを可能にするものだということを思い出してほしい。
上の例を`andThen`を利用して書くことができる:

```scala
val aToC = aToB andThen bToC
```

結果は、`A`型の値に関数を次々に適用する、`A => F[C]`という型を持つ(ラップされた)関数`aToC`である。

`example`メソッドのように`A`型の引数を参照することなく、同じことを成し遂げたのだ。
`Check`の`andThen`メソッドは関数合成のようなものだが、`A => B`ではなく`A => F[B]`型の関数を合成する。

`A => F[B]`という型の関数を合成するという概念を抽象化したものには名前がついている: **クライスリ(Kleisli)** だ。

Cats は、`Check`がやっているのと同じように関数を包む[`cats.data.Kleisli`][cats.data.Kleisli]データ型を持っている。
`Kleisli`は`Check`が持つすべてのメソッドに加え、いくつか追加のメソッドを持つ。
`Kleisli`に見覚えがある? おめでとう。
あなたは本書の前の方で出てきた別の概念の変装を見破ることに成功した:
`Kleisli`は`ReaderT`の単なる別名なのだ。

`Kleisli`を利用して、3ステップで整数を整数のリストに変換する簡単な例を挙げる:

```tut:book:silent
import cats.data.Kleisli
import cats.instances.list._ // for Monad
```

これらのステップのそれぞれが入力の`Int`を`List[Int]`型の出力に変換する:

```tut:book:silent
val step1: Kleisli[List, Int, Int] =
  Kleisli(x => List(x + 1, x - 1))

val step2: Kleisli[List, Int, Int] =
  Kleisli(x => List(x, -x))

val step3: Kleisli[List, Int, Int] =
  Kleisli(x => List(x * 2, x / 2))
```

これらのステップを、内部で`flatMap`を利用して`List`を結合するような、1つのパイプラインに合成することができる。

```tut:book:silent
val pipeline = step1 andThen step2 andThen step3
```

この結果は、1つの`Int`を消費し、`step1`、`step2`、`step3`の変換の別々の組み合わせによって生成された8つの`Int`のリストを出力するような関数となる:

```tut:book
pipeline.run(20)
```

`Kleisli`と`Check`の API における唯一注意すべき違いは、我々の`apply`メソッドが`Kleisli`では`run`という名前に変わっていることだ。

妥当性検査の例の`Check`を`Kleisli`で置き換えてみよう。
そのためには`Predicate`にいくつかの変更を行う必要がある。
`Kleisli`は関数しか扱えないので、`Predicate`を関数に変換できるようにしなければならない。
また、細かいことだが、`Predicate`を関数に変換する際は、`A => Validated[E, A]`ではなく`A => Either[E, A]`型の関数を返す必要がある。これは`Kleisli`がモナドを返す関数に依存するためだ。


`Predicate`に、正しい型の関数を返すような`run`という名前のメソッドを追加せよ。
`Predicate`の残りのコードはそのままにしておくこと。

<div class="solution">
`run`の定義の省略形を以下に示す。
`apply`のような、このメソッドは暗黙の`Semigroup`を受け取らなければならない:

```tut:book:silent
import cats.Semigroup
import cats.data.Validated
```

```tut:book:silent
sealed trait Predicate[E, A] {
  def run(implicit s: Semigroup[E]): A => Either[E, A] =
    (a: A) => this(a).toEither

  def apply(a: A): Validated[E, A] =
    ??? // ...

  // 他のメソッド...
}
```
</div>

これで、ユーザ名とEメールアドレスの妥当性検査の例を`Kleisli`と`Predicate`を利用して書き換えることができる。
行き詰まったときのために、いくつかヒントを与えよう:

まず、`Predicate`の`run`メソッドは暗黙の引数をとることを思い出そう。
`aPredicate.run(a)`という呼び出しを行うと、暗黙の引数を明示的に渡すことになる。
`Predicate`から関数を生成してすぐに適用したければ、`aPredicate.run.apply(a)`と書こう。

また、この演習では型推論がトリッキーなものになる。
次に示す定義が、より少ない型宣言でコードを書く助けになるようだ。

```scala
type Result[A] = Either[Errors, A]

type Check[A, B] = Kleisli[Result, A, B]

// 関数からチェックを生成する
def check[A, B](func: A => Result[B]): Check[A, B] =
  Kleisli(func)

// Predicate からチェックを生成する
def checkPred[A](pred: Predicate[Errors, A]): Check[A, A] =
  Kleisli[Result, A, A](pred.run)
```

<div class="solution">
```tut:book:invisible:reset
// Foreword declarations

import cats.Semigroup
import cats.syntax.apply._     // for mapN
import cats.syntax.semigroup._ // for |+|
import cats.data.Validated
import cats.data.Validated.{Valid, Invalid}

object wrapper {
  sealed trait Predicate[E, A] {
    import Predicate._

    def and(that: Predicate[E, A]): Predicate[E, A] =
      And(this, that)

    def or(that: Predicate[E, A]): Predicate[E, A] =
      Or(this, that)

    def run(implicit s: Semigroup[E]): A => Either[E, A] =
      (a: A) => this(a).toEither

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

    def lift[E, A](error: E, func: A => Boolean): Predicate[E, A] =
      Pure(a => if(func(a)) Valid(a) else Invalid(error))
  }
}; import wrapper._
```

このコードを書く際に型推論の限界に対処するのは、非常にもどかしいことだろう。
`Predicate`と関数、`Validated`と`Either`をいつ変換すればいいのかを理解できれば物事は単純になるが、そのプロセスはやはり複雑になる:

```tut:book:silent
import cats.data.{Kleisli, NonEmptyList, Validated}
import cats.instances.either._   // for Semigroupal
import cats.instances.list._     // for Monad
```

これは事例の本文で提案したプリアンブルだ:

```tut:book:silent
type Errors = NonEmptyList[String]

def error(s: String): NonEmptyList[String] =
  NonEmptyList(s, Nil)

type Result[A] = Either[Errors, A]

type Check[A, B] = Kleisli[Result, A, B]

def check[A, B](func: A => Result[B]): Check[A, B] =
  Kleisli(func)

def checkPred[A](pred: Predicate[Errors, A]): Check[A, A] =
  Kleisli[Result, A, A](pred.run)
```

`Predicate`の定義は、本質的には変わらない:

```tut:book:silent
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
```

ユーザ名とEメールアドレスの例は、`check()`と`checkPred()`を状況に応じて使い分けるという点で、少々異なったものになる:

```tut:book:silent
val checkUsername: Check[String, String] =
  checkPred(longerThan(3) and alphanumeric)

val splitEmail: Check[String, (String, String)] =
  check(_.split('@') match {
    case Array(name, domain) =>
      Right((name, domain))

    case other =>
      Left(error("Must contain a single @ character"))
  })

val checkLeft: Check[String, String] =
  checkPred(longerThan(0))

val checkRight: Check[String, String] =
  checkPred(longerThan(3) and contains('.'))

val joinEmail: Check[(String, String), String] =
  check {
    case (l, r) =>
      (checkLeft(l), checkRight(r)).mapN(_ + "@" + _)
  }

val checkEmail: Check[String, String] =
  splitEmail andThen joinEmail
```

最後に、`createUser`の例が`Kleisli`を利用して期待通りに動作していることを確認する:

```tut:book:silent
final case class User(username: String, email: String)

def createUser(
      username: String,
      email: String): Either[Errors, User] = (
  checkUsername.run(username),
  checkEmail.run(email)
).mapN(User)
```

```tut:book
createUser("Noel", "noel@underscore.io")
createUser("", "dave@underscore@io")
```
</div>

これで、コードからすべての`Check`を取り除き、`Kleisli`と`Predicate`で書き換えたことになる。
これはライブラリをシンプルにする良きはじめの一歩である。
まだできることはたくさんあるが、我々には Cats の洗練されたコード構成ブロックがある。
これ以上の改良は読者への課題とする。
