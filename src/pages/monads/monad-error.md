## 余談: エラー処理と MonadError

Cats はエラー処理に利用される`Either`のようなデータ型を抽象化した、`MonadError`という型クラスを追加で提供している。
`MonadError`は、エラーを送出し、処理する追加の操作を持っている。

<div class="callout callout-info">
**この節は読み飛ばしてもかまわない!**

エラー処理モナドを抽象化する必要がなければ、`MonadError`を利用する必要はないだろう。
例えば、`Future`と`Try`、または`Either`と`EitherT`(これは[@sec:monad-transformers]章で見ることになる)を抽象化するのに`MonadError`を利用できる。

このような抽象化を行う必要に迫られていないのであれば、[@sec:monads:eval]節まで飛ばしてもかまわない。
</div>

### MonadError 型クラス

`MonadError`の定義を簡略化したものを以下に示す:

```scala
package cats

trait MonadError[F[_], E] extends Monad[F] {
  // エラーを`F`という文脈に持ち上げる
  def raiseError[A](e: E): F[A]

  // エラーを処理する。エラーからの回復を行うこともある
  def handleError[A](fa: F[A])(f: E => A): F[A]

  // `F`型のインスタンスを検査し、
  // 条件を満たしていなければ失敗させる
  def ensure[A](fa: F[A])(e: E)(f: A => Boolean): F[A]
}
```

`MonadError`は2つの型パラメータによって定義される:

- `F`: モナドの型
- `E`: `F`に含まれるエラーの型

これらの型がどのように噛み合うのかを示すために、`Either`に対するインスタンスを生成する例を以下に示す:

```tut:book:silent
import cats.MonadError
import cats.instances.either._ // for MonadError

type ErrorOr[A] = Either[String, A]

val monadError = MonadError[ErrorOr, String]
```

<div class="callout callout-warning">
**ApplicativeErrorについて**

実際には、`MonadError`は`ApplicativeError`と呼ばれる他の型クラスを継承している。
しかし、[@sec:applicatives]章になるまで`Applicative`に出会うことはない。
これらの型クラスが持つ意味は同様なので、今はこの詳細を無視してかまわない。
</div>

### エラーの送出と処理

`MonadError`の最も重要な2つのメソッドは、`raiseError`と`handleError`である。
`raiseError`は`Monad`の`pure`メソッドに似ているが、失敗を表現する値を生成する:

```tut:book
val success = monadError.pure(42)
val failure = monadError.raiseError("Badness")
```

`handleError`は`raiseError`を補完するメソッドである。
これは、`Future`の`recover`メソッドに似た、エラーを消費して(可能なら)それを成功に変える、という処理を可能にする:

```tut:book
monadError.handleError(failure) {
  case "Badness" =>
    monadError.pure("It's ok")

  case other =>
    monadError.raiseError("It's not ok")
}
```

3番目に便利な`ensure`メソッドは、`filter`のような振る舞いを実装している。
これは、成功を表すモナド値を条件を表す関数によって検査し、その条件関数が`false`を返したときに指定したエラーを送出することができる:

```tut:book:silent
import cats.syntax.either._ // for asRight
```

```tut:book
monadError.ensure(success)("Number too low!")(_ > 1000)
```

Cats は、[`cats.syntax.applicativeError`][cats.syntax.applicativeError]によって`raiseError`と`handleError`の構文を、[`cats.syntax.monadError`][cats.syntax.monadError]によって`ensure`の構文を提供している:

```tut:book:silent
import cats.syntax.applicative._      // for pure
import cats.syntax.applicativeError._ // for raiseError etc
import cats.syntax.monadError._       // for ensure
```

```tut:book
val success = 42.pure[ErrorOr]
val failure = "Badness".raiseError[ErrorOr, Int]
success.ensure("Number to low!")(_ > 1000)
```

他にも便利な派生メソッドがある。
詳しくは、[`cats.syntax.MonadError`][cats.MonadError]と[`cats.ApplicativeError`][cats.ApplicativeError]のソースを参照してほしい。

### MoandError のインスタンス

Cats には、`Either`、`Future`、`Try`を含む多くのデータ型に対する`MonadError`のインスタンスがある。
`Either`に対するインスタンスは任意のエラー型を利用してカスタマイズできるが、一方`Future`と`Try`に対するインスタンスは常に`Throwable`の形でエラーを表現する:

```tut:book:silent
import scala.util.Try
import cats.instances.try_._ // for MonadError

val exn: Throwable =
  new RuntimeException("It's all gone wrong")
```

```tut:book
exn.raiseError[Try, Int]
```
