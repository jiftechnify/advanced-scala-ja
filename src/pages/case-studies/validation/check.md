## チェックのデータ型

我々の設計では、`Check`を中心に据える。これは先程述べたような、値を「文脈の中の値」に変換する関数である。
この説明を聞けば、すぐに次のようなものを考えるだろう:

```tut:book:silent
type Check[A] = A => Either[String, A]
```

ここではエラーメッセージを`String`として表現した。
これは最適な表現ではないかもしれない。
国際化や標準的なエラーコードを表現できるよう、別の表現、例えば`List`に、メッセージを蓄積する必要があるだろう。

考えうる限りの情報をすべて含むような`ErrorMessage`のような型を構成してみることもできるだろう。
しかし、ユーザの要求を予測することはできない。
代わりに、ユーザが好きな型を指定できるようにしよう。
これは、`Check`に2つ目の型パラメータを追加することで可能となる:

```tut:book:silent
type Check[E, A] = A => Either[E, A]
```

`Check`に独自のメソッドを追加するかもしれないので、これを型エイリアスではなく`trait`として宣言しよう:

```tut:book:silent
trait Check[E, A] {
  def apply(value: A): Either[E, A]

  // 他のメソッド...
}
```

[Essential Scala][link-essential-cala]で説明したように、トレイトを定義する際に考慮すべき、2つの関数プログラミングパターンがある:

- それを型クラスにできないか?
- それを代数的データ型にできないか? (この場合は、`sealed`をつける)

型クラスは、異なるデータ型に共通するインターフェイスを統合することを可能にする。
これは、ここでしようとしていることではなさそうだ。
残ったのは代数的データ型だ。
この考えを心に留めながら、設計をもう少し深く調べていこう。

## 基本のコンビネータ

`Check`にいくつかのコンビネータを追加していこう。まず`and`だ。
このメソッドは2つのチェックを1つに合成する。これは、両方のチェックが成功した時に限り成功する。
ここで、このメソッドの実装について考えてみよう。
何らかの問題に直面することになるだろう。そうなったら、続きを読み進めよう!

```tut:book:silent
trait Check[E, A] {
  def and(that: Check[E, A]): Check[E, A] =
    ???

  // 他のメソッド...
}
```

問題とは: **両方の** チェックが失敗した際にどうすればいいだろうか? というものだ。
正しい方法は両方のエラーを返すというものだが、今のところ2つの`E`を組み合わせる方法はない。
図[@fig:validation:error-semigroup]に示したような、エラーの「蓄積」という概念を抽象化する **型クラス** が必要となる。
このような型クラスを見たことがないだろうか?
`•`演算を実装するには、どのメソッドまたは演算子を利用すればいいだろうか?

![エラーメッセージの合成](src/pages/case-studies/validation/error-semigroup.pdf+svg){#fig:validation:error-semigroup}

<div class="solution">
`E`に対する`Semigroup`が必要となる。
`combine`メソッド、または関連する`|+|`構文を利用して`E`型の値を組み合わせることができる:

```tut:book:silent
import cats.Semigroup
import cats.instances.list._   // for Semigroup
import cats.syntax.semigroup._ // for |+|

val semigroup = Semigroup[List[String]]
```

```tut:book
// Semigroup のメソッドを利用した合成
semigroup.combine(List("Badness"), List("More badness"))

// Semigroup の構文を利用した合成
List("Oh noes") |+| List("Fail happened")
```

単位元は必要ないので、完全な`Monoid`は必要ないということに注意せよ。
常に、制約はできるだけ小さくするように心がけよう!
</div>

すぐに、もうひとつの意味論的な問題が浮上する:
`and`は1つ目のチェックが失敗した場合に短絡的に動作するべきだろうか。
これが最も有用な振る舞いなのだろうか?

<div class="solution">
できる限りすべてのエラーを報告したいので、可能ならば短絡評価を **しない** 方が好ましい。

`and`メソッドの場合、合成する2つのチェックはお互いに独立である。
常に両方のルールを実行し、発生したすべてのエラーを結合できる。
</div>

この知見を利用して`and`を実装せよ。
期待する振る舞いとなっているかどうか確認するのを忘れないでほしい!

<div class="solution">
少なくとも2つの実装方針がある。

1つ目の方針では、チェックを関数の形で表現する。
`Check`データ型は、ライブラリにコンビネータメソッドをもたらす、単なる関数のラッパーとなる。
混乱をなくすために、この実装を`CheckF`と呼ぶことにする:

```tut:book:silent
import cats.Semigroup
import cats.syntax.either._    // for asLeft and asRight
import cats.syntax.semigroup._ // for |+|
```

```tut:book:silent
final case class CheckF[E, A](func: A => Either[E, A]) {
  def apply(a: A): Either[E, A] =
    func(a)

  def and(that: CheckF[E, A])
        (implicit s: Semigroup[E]): CheckF[E, A] =
    CheckF { a =>
      (this(a), that(a)) match {
        case (Left(e1) , Left(e2))  => (e1 |+| e2).asLeft
        case (Left(e)  , Right(a))  => e.asLeft
        case (Right(a) , Left(e))   => e.asLeft
        case (Right(a1), Right(a2)) => a.asRight
      }
    }
}
```

振る舞いをテストしてみよう。
まずいくつかのチェックを設定する:

```tut:book:silent
import cats.instances.list._ // for Semigroup

val a: CheckF[List[String], Int] =
  CheckF { v =>
    if(v > 2) v.asRight
    else List("Must be > 2").asLeft
  }

val b: CheckF[List[String], Int] =
  CheckF { v =>
    if(v < -2) v.asRight
    else List("Must be < -2").asLeft
  }

val check: CheckF[List[String], Int] =
  a and b
```

いくつかのデータをチェックする:

```tut:book
check(5)
check(0)
```

素晴らしい! すべて思ったとおりに動作している!
両方のチェックを実行し、要求通りエラーを蓄積している。

蓄積できない型の値とともに失敗するチェックを生成しようとすると何が起こるだろうか?
例えば、`Nothing`に対する`Semigroup`のインスタンスは存在しない。
`CheckF[Nothing, A]`のインスタンスを生成すると、どうなるのだろうか?

```tut:book:silent
val a: CheckF[Nothing, Int] =
  CheckF(v => v.asRight)

val b: CheckF[Nothing, Int] =
  CheckF(v => v.asRight)
```

問題なくチェックを生成できるが、これらを組み合わせようとすると、期待通りエラーとなる:

```tut:book:fail
val check = a and b
```

さて、もうひとつの実装方針を見ていこう。
このアプローチでは、チェックを、それぞれのコンビネータに対して明示的なデータ型を持つような代数的データ型としてモデル化する。
この実装を`Check`と呼ぶことにする:

```tut:book:invisible:reset
import cats.Semigroup
import cats.instances.list._   // for Semigroup
import cats.syntax.either._    // for asLeft and asRight
import cats.syntax.semigroup._ // for |+|
```

```tut:book:silent
object wrapper {
  sealed trait Check[E, A] {
    def and(that: Check[E, A]): Check[E, A] =
      And(this, taht)

    def apply(a: A)(implicit s: Semigroup[E]): Either[E, A] =
      this match {
        case Pure(func) =>
          func(a)

        case And(left, right) =>
          (left(a), right(a)) match {
            case (Left(e1) , Left(e2))  => (e1 |+| e2).asLeft
            case (Left(e)  , Right(a))  => e.asLeft
            case (Right(a) , Left(e))   => e.asLeft
            case (Right(a1), Right(a2)) => a.asRight
          }
      }
  }

  final case class And[E, A](
    left: Check[E, A],
    right: Check[E, A]) extends Check[E, A]

  final case class Pure[E, A](
    func: A => Either[E, A]) extends Check[E, A]
}; import wrapper._
```

使用例を見てみよう:

```tut:book:silent
val a: Check[List[String], Int] =
  Pure { v =>
    if(v > 2) v.asRight
    else List("Must be > 2").asLeft
  }

val b: Check[List[String], Int] =
  Pure { v =>
    if(v < -2) v.asRight
    else List("Must be < -2").asLeft
  }

val check: Check[List[String], Int] =
  a and b
```

ADT による実装は関数のラッパーによる実装よりも冗長だが、計算の構造(生成する ADT のインスタンス)と、それに意味を与えるプロセス(`apply`メソッド)がきれいに分離されるという利点がある。
これにより、いくつかの追加機能を追加できる:

- チェックを生成した後にその構造を調べ、最適化できる
- `apply`という「インタプリタ」をそのモジュールの外に移動できる
- 他の機能を提供する別のインタプリタを実装できる(例えば、チェックの可視化)

この事例研究では今後、柔軟性の高い ADT による実装を利用していくことにする。
</div>

正確にいうと、`Either[E, A]`はチェックの出力の抽象化としては間違いである。これはなぜだろうか?
代わりに利用できる他のデータ型はないだろうか?
この新しいデータ型を利用し、実装を変更せよ。

<div class="solution">
`And`に対する`apply`の実装はアプリカティブファンクタのパターンを利用している。
`Either`は`Applicative`のインスタンスを持つが、そのセマンティクスは望んでいるものではない。
これはエラーを蓄積せず、最初に失敗した時点で終了してしまう(フェイルファストである)。

エラーを蓄積したい場合、`Validated`がより適切な抽象化である。
おまけに、`apply`の実装で`Validated`のアプリカティブのインスタンスを利用できるので、多くのコードを再利用できる。

以下に完全な実装を示す:

```tut:book:silent
import cats.Semigroup
import cats.data.Validated
import cats.syntax.semigroup._ // for |+|
import cats.syntax.apply._     // for mapN
```

```tut:book:silent
object wrapper {
  sealed trait Check[E, A] {
    def and(that: Check[E, A]): Check[E, A] =
      And(this, that)

    def apply(a: A)(implicit s: Semigroup[E]): Validated[E, A] =
      this match {
        case Pure(func) =>
          func(a)

        case And(left, right) =>
          (left(a), right(a)).mapN((_, _) => a)
      }
  }

  final case class And[E, A](
    left: Check[E, A],
    right: Check[E, A]) extends Check[E, A]

  final case class Pure[E, A](
    func: A => Validated[E, A]) extends Check[E, A]
}; import wrapper._
```
</div>

今や、実装はかなり良くなった。
`and`を補完する`or`コンビネータを実装せよ。

<div class="solution">
`and`と同じテクニックを再利用できる。
`apply`メソッドに少し手を加える必要がある。
この場合は、`or`のセマンティクスがルールを選択する戦略を暗示しているので、短絡的な動作でも問題ない。

```tut:book:silent
import cats.Semigroup
import cats.data.Validated
import cats.syntax.semigroup._ // for |+|
import cats.syntax.apply._     // for mapN
import cats.data.Validated._   // for Valid and Invalid
```

```tut:book:silent
object wrapper {
  sealed trait Check[E, A] {
    def and(that: Check[E, A]): Check[E, A] =
      And(this, that)

    def or(that: Check[E, A]): Check[E, A] =
      Or(this, that)

    def apply(a: A)(implicit s: Semigroup[E]): Validated[E, A] =
      this match {
        case Pure(func) =>
          func(a)

        case And(left, right) =>
          (left(a), right(a)).mapN((_, _) => a)

        case Or(left, right) =>
          left(a) match {
            case Valid(a)    => Valid(a)
            case Invalid(e1) =>
              right(a) match {
                case Valid(a)   => Valid(a)
                case Invalid(e2) => Invalid(e1 |+| e2)
              }
          }
      }
  }

  final case class And[E, A](
    left: Check[E, A],
    right: Check[E, A]) extends Check[E, A]

  final case class Or[E, A](
    leftL Check[E, A],
    right: Check[E, A]) extends Check[E, A]

  final case class Pure[E, A](
    func: A => Validated[E, A]) extends Check[E, A]
}; import wrapper._
```
</div>

`and`と`or`を利用することで、多くの実用的なチェックを実装できる。
しかし、まだいくつかのメソッドを追加する必要がある。
次は、`map`とそれに関連するメソッドを見ていく。
