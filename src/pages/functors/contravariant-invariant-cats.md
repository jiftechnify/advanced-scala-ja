## Cats における反変・非変ファンクタ

Cats における反変ファンクタと非変ファンクタの実装を見ていこう。
これらはそれぞれ[`cats.Contravariant`][cats.Contravariant]と[`cats.Invariant`][cats.Invariant]型クラスによって提供されている。
以下に簡略化したコードを示す:

```tut:book:invisible
import scala.language.higherKinds
```

```tut:book:silent
trait Contravariant[F[_]] {
  def contramap[A, B](fa: F[A])(f: B => A): F[B]
}

trait Invariant[F[_]] {
  def imap[A, B](fa: F[A])(f: A => B)(g: B => A): F[B]
}
```

### Cats における反変ファンクタ

`Contravariant.apply`メソッドを利用することで`Contravariant`のインスタンスを召喚することができる。
Cats は、`Eq`、`Show`、`Function1`のような、引数を「消費」するデータ型に対する反変ファンクタのインスタンスを提供している。
以下に例を示す:

```tut:book:silent
import cats.Contravariant
import cats.Show
import cats.instances.string._

val showString = Show[String]

val showSymbol = Contravariant[Show].
  contramap(showString)((sym: Symbol) => s"'${sym.name}")
```

```tut:book
showSymbol.show('dave)
```

より便利な、[`cats.syntax.contravariant`][cats.syntax.contravariant]が提供する`contramap`拡張メソッドを利用することもできる:

```tut:book:silent
import cats.syntax.contravariant._ // for contramap
```

```tut:book
showString.contramap[Symbol](_.name).show('dave)
```

### Cats における非変ファンクタ

Cats が`Monoid`に対する`Invariant`のインスタンスを提供していることは特筆に値する。
これは[@sec:functors:invariant]節で紹介した `Codec`の例とは少々異なっている。

`Monoid`が次のようなものであることを覚えているだろうか:

```scala
package cats

trait Monoid[A] {
  def empty: A
  def combine(x: A, y: A): A
}
```

Scalaの [`Symbol`][link-symbol]型に対する`Monoid`を作りたいとしよう。
Cats は`Symbol`に対する`Monoid`インスタンスは提供していないが、`String`というよく似た型に対する`Monoid`を提供している。
空の`String`に基づく`empty`メソッドと、次のように動作する`combine`メソッドを持つ、新しいモノイドを書くことができる:

1. 2つの`Symbol`を引数として受け取る
2. `Symbol`を`String`に変換する
3. `Monoid[String]`を利用して変換後の`String`を結合する
4. その結果を`Symbol`に変換する

`String => Symbol`型と`Symbol => String`型の関数を引数にとる`imap`を利用して、`combine`を実装できる。
以下のコードは、`cats.syntax.invariant`が提供する`imap`拡張メソッドを利用してこれを実装したものである:

```tut:book:silent
import cats.Monoid
import cats.instances.string._ // for Monoid
import cats.syntax.invariant._ // for imap
import cats.syntax.semigroup._ // for |+|

implicit val symbolMonoid: Monoid[Symbol] =
  Monoid[String].imap(Symbol.apply)(_.name)
```

```tut:book
Monoid[Symbol].empty

'a |+| 'few |+| 'words
```
