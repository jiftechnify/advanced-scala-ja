# Semigroupal と Applicative {#sec:applicatives}

これまでの章では、ファンクタやモナドの`map`や`flatMap`を利用してどのように計算を連鎖させればいいかについて見てきた。
ファンクタとモナドはどちらも非常に有用な抽象化であるが、それでも表現できない種類のプログラムフローが存在する。

そのような例として、フォームの入力値検証が挙げられる。
フォームの検証を行う際は、最初に出会ったエラーで停止せずに、ユーザに **すべての** エラーを返したい。
これを`Either`のようなモナドでモデリングすると、フェイルファストなエラー処理となり
エラー情報が失われてしまう。
例えば、以下のコードは最初の`parseInt`の呼び出しで失敗し、それ以上先に進むことはない:

```tut:book:silent
import cats.syntax.either._ // for catchOnly

def parseInt(str: String): Either[String, Int] =
  Either.catchOnly[NumberFormatException](str.toInt).
    leftMap(_ => s"Couldn't read $str")
```

```tut:book
for {
  a <- parseInt("a")
  b <- parseInt("b")
  c <- parseInt("c")
} yield (a + b + c)
```

もうひとつの例としては、`Future`の並列評価が挙げられる。
いくつかの、独立した、実行に時間のかかるタスクがあるとき、それらを並列に実行するのは有意義である。
しかし、モナド内包表記ではそれらを逐次的に実行することしかできない。
`map`や`flatMap`は、それぞれの計算がそれまでの計算に **依存する** ことを仮定しているので、ここでしたいこと(並列実行)を捉えるのに十分な能力を持っていない。

```scala
// context2 は value1 に依存する:
context1.flatMap(value1 => context2)
```

上の`parseInt`と`Future.apply`の呼び出しはお互いに **独立** しているが、`map`や`flatMap`はそのことを活かすことができない。
求めている結果を得るには、逐次実行を保証しないような、より弱い構造が必要となる。
本章では、このパターンをサポートする2つの型クラスを見ていく。

  - `Semigroupal`: 文脈の組の合成という概念を含む型クラス。
    Cats は`Semigroupal`と`Functor`を利用して複数の引数を持つ関数の連鎖を可能にする、[`cats.syntax.apply`][cats.syntax.apply]モジュールを提供している。

  - `Applicative`: `Semigroupal`と`Functor`を継承する型クラス。
    これは文脈の中にある複数の引数に関数を適用する方法を提供している。
    `Applicative`は、[@sec:monads]で紹介した`pure`メソッドの出どころである。

アプリカティブは、Cats においては semigroupal による定式化が強調されているのと対照的に、関数適用の言葉で定式化されることが多い。
このもうひとつの定式化は、 Scalaz や Haskell のような他のライブラリ・言語との繋がりをもたらす。
本章では、アプリカティブの異なる定式化の方法や`Semigroupal`、`Functor`、`Applicative`、そして`Monad`の間にある関係について見ていく。
