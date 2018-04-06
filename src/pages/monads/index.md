# モナド {#sec:monads}

**モナド** は Scala において最もありふれた抽象化手法のひとつである。
多くの Scala プログラマはすぐに、(その名前を知ることはなくとも)モナドに精通することになる。

形式ばらずにいえば、モナドとはコンストラクタと`flatMap`メソッドを持つすべてである。
`Option`、`List`、`Future`を含む、前章で見たすべてのファンクタはモナドでもある。
さらに、モナドをサポートする特別な構文も用意されている: for 内包表記(for comprehension)だ。
しかし、その概念の普遍性にもかかわらず、Scala 標準ライブラリは「`flatMap`できるもの」を指す具体的な型を欠いている。
この型クラスは Cats によって提供される恩恵のひとつである。

本章ではモナドを深く掘り下げていく。
まずいくつかの例によってその動機を知ることから始める。
そして、モナドの形式的な定義と Cats におけるその実装を見る。
最後に、あなたがまだ見たことがないかもしれない興味深いモナドの数々を、その解説と使用例を交えながら見て回ることにする。

## モナドとは何か?

この問いはこれまでに数千のブログ記事で提起され、その度に説明や比喩が付け加えられてきた。その比喩は猫、メキシコの食べ物、有毒なゴミでいっぱいの宇宙服、そして自己関手の圏におけるモノイド対象(それが何を意味するにせよ)など多岐にわたる。
モナドの意味を次のように非常にシンプルに述べることで、モナドの説明という問題を今回きりで解決してしまおう:

> モナドは **逐次的な計算** のための仕組みである。

なんと簡単なのだろうか! これで問題は解決しただろう?
しかし、前章で、ファンクタはまさにこれと同じような制御機構であると説明したではないか。
わかった、もう少し議論を進めることにしよう…

[@sec:functors:examples]節において、ファンクタは何らかの「複雑な状態」を無視しながら計算を連鎖させることを可能にするものだと説明した。
しかし、ファンクタでは計算列の最初でしか、この複雑な状態を扱うことができない。
ファンクタは、計算の連鎖の各ステップで追加で発生する複雑な状態については何も関知しないのだ。

そこでモナドの登場である。
モナドの`flatMap`メソッドによって、複雑な中間状態を考慮に入れつつ、次に何が起こるかを指定することが可能となる。
`Option`の`flatMap`メソッドは中間状態としての`Option`を考慮に入れる。
`List`の`flatMap`メソッドは中間状態としての `List`を扱う。以下同様だ。
それぞれの場合において、`flatMap`に渡される関数は計算の「アプリケーション特有」の部分を指定し、`flatMap`自身は、その結果に再び`flatMap`を適用できるようにしながら、複雑な状態を扱う。
いくつかの例を見て、理解を深めていこう。

**Option**

`Option`は、値を返すかもしれないし、返さないかもしれないような計算を連鎖させることを可能にする。
以下に例を挙げる:

```tut:book:silent
def parseInt(str: String): Option[Int] =
  scala.util.Try(str.toInt).toOption

def divide(a: Int, b: Int): Option[Int] =
  if(b == 0) None else Some(a / b)
```

それぞれのメソッドは`None`を返して「失敗」する可能性がある。
`flatMap`メソッドは、操作を繋げるときにこの失敗を無視できるようにする:

```tut:book:silent
def stringDivideBy(aStr: String, bStr: String): Option[Int] =
  parseInt(aStr).flatMap { aNum =>
    parseInt(bStr).flatMap { bNum =>
      divide(aNum, bNum)
    }
  }
```

これの意味についてはご存知だろう:

- 1つ目の`parseInt`の呼び出しは`None`または`Some`を返す
- その返り値が`Some`なら、`flatMap`メソッドは引数の関数に`aNum`を渡して呼び出す
- 2つ目の`parseInt`の呼び出しも`None`または`Some`を返す
- その返り値が`Some`なら、`flatMap`メソッドは引数の関数に`bNum`を渡して呼び出す
- `divide`の呼び出しは`None`または`Some`を返し、これが最後の結果となる。

各ステップにおいて`flatMap`は渡された関数を呼ぶかどうかを選択し、渡した関数は計算の列における次の計算を生成する。
この様子を図[@fig:monads:option-type-chart]に示す。

![型チャート: Option の flatMap](src/pages/monads/option-flatmap.pdf+svg){#fig:monads:option-type-chart}

計算の結果は`Option`となるので、`flatMap`を再び呼び出すことでさらに計算を連鎖させることができる。
これは、よく知られ、好まれているフェイルファストなエラー処理の振る舞いとなる。ある計算ステップで`None`が返ると、全体の結果も`None`となる:

```tut:book
stringDivideBy("6", "2")
stringDivideBy("6", "0")
stringDivideBy("6", "foo")
stringDivideBy("bar", "2")
```

すべてのモナドはファンクタでもある(証明は後述する)。よって、新しいモナド値を導入する計算、導入しない計算をそれぞれの`flatMap`、`map`を利用して計算列に繋ぐことができる。
さらに、`flatMap`と`map`の両方があれば、for 内包表記を利用して逐次的な振る舞いをより明確に示すことができる:

```tut:book:silent
def stringDivideBy(aStr: String, bStr: String): Option[Int] =
  for {
    aNum <- parseInt(aStr)
    bNum <- parseInt(bStr)
    ans  <- divide(aNum, bNum)
  } yield ans
```

**リスト**

Scala 開発者の駆け出しの頃、初めて`flatMap`に出会った際、多くの人はそれを`List`を反復処理するためのパターンだと考えがちである。
この考え方は、命令型プログラムの for ループによく似た for 内包表記の構文によって確固たるものになる:

```tut:book
for {
  x <- (1 to 3).toList
  y <- (4 to 5).toList
} yield (x, y)
```

しかし、`List`のモナド的振る舞いを強調するもう1つのメンタルモデルがある。
`List`を中間結果の集合と考えると、`flatMap`は順列や組み合わせを計算するための構成概念となる。

例えば、上記の for 内包表記では`x`は3種類の、`y`は2種類の値をとる可能性がある。
よって、`(x, y)`は全部で6種類の値をとる可能性がある。
`flatMap`は次のような操作の列を実行し、すべての組み合わせ`(x, y)`を生成する:

- `x`を取得
- `y`を取得
- `(x, y)`という組を生成

**Future**

`Future`は計算が非同期に実行される可能性を気にすることなく、それらの計算を連鎖させることができるモナドである:

```tut:book:silent
import scala.concurrent.Future
import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.duration._

def doSomethingLongRunning: Future[Int] = ???
def doSomethingElseLongRunning: Future[Int] = ???

def doSomethingVeryLongRunning: Future[Int] =
  for {
    result1 <- doSomethingLongRunning
    result2 <- doSomethingElseLongRunning
  } yield result1 + result2
```

今回も、必要なのは各ステップで実行するコードを指定することだけで、`flatMap`がスレッドプールやスケジューラのような、おぞましく複雑な内部状態の面倒を見てくれている。

`Future`をよく使うならば、上のコードがそれぞれの計算を **順番に** 実行するのをご存知だろう。
for 内包表記をネストした`flatMap`の呼び出しに展開すれば、このことがよりはっきり分かるだろう:

```tut:book:silent
def doSomethingVeryLongRunning: Future[Int] =
  doSomethingLongRunning.flatMap { result1 =>
    doSomethingElseLongRunning.map { result2 =>
      result1 + result2
    }
  }
```

連鎖の中のそれぞれの`Future`は、前にある`Future`の結果を受け取る関数によって生成される。
言い換えれば、計算の各ステップは前のステップが終わってはじめて開始できるようになる。
このことが`flatMap`についての型チャート(図[@fig:monads:future-type-chart])によって裏付けられる。これによれば、`flatMap`の引数の型は`A => Future[B]`である。

![型チャート: Future の flatMap](src/pages/monads/future-flatmap.pdf+svg){#fig:monads:future-type-chart}

もちろん、Future を並列に実行することも **可能である** が、それは別の話であり、またの機会に説明するつもりだ。
モナドは逐次実行に関するすべてなのだ。

### モナドの定義

ここまで`flatMap`についてしか説明してこなかったが、モナド的な振る舞いは形式的には2つの演算によって捉えられる:

- `pure` (`A => F[A]`型)
- `flatMap`[^bind] (`(F[A], A => F[B]) => F[B]`型)

[^bind]: Scalaz や Haskell でみられるように、ライブラリや言語によっては`pure`を`point`または`return`と、`flatMap`を`bind`または`>>=`と呼ぶことがある。
これは単に用語の違いである。
本書では、Cats や Scala 標準ライブラリとの互換性のため`flatMap`という用語を用いる。

`pure`はコンストラクタの抽象化である。これは純粋な値からモナド的文脈を生成する方法を提供する。
`flatMap`は、既に見たように、計算ステップを繋げるための方法である。文脈から値を取り出し、計算の連鎖に新しい文脈を追加する。
Cats における`Monad`型クラスを簡略化したのが以下のコードである:

```tut:book:silent
import scala.language.higherKinds

trait Monad[F[_]] {
  def pure[A](value: A): F[A]

  def flatMap[A, B](value: F[A])(func: A => F[B]): F[B]
}
```

<div class="callout callout-warning">
**モナドの法則**

`pure`と`flatMap`は、意図しないバグや副作用を起こすことなく計算を連鎖させることができるよう、いくつかの法則に従わなければならない:

**左単位元の法則**: `pure`の結果を関数`func`で変換したとき、その結果は単に`func`を呼び出したのと等価でなければならない:

```scala
pure(a).flatMap(func) == func(a)
```

**右単位元の法則**: `flatMap`に`pure`を渡して呼び出すことは、何もしないのと等価でなければならない:

```scala
m.flatMap(pure) == m
```

**結合則**: `f`と`g`の2つの関数をある意味で「合成した」関数によって`flatMap`した結果と、`f`で`flatMap`し、続けて`g`で`flatMap`した結果は等価でなければならない:

```scala
m.flatMap(f).flatMap(g) == m.flatMap(x => f(x).flatMap(g))
```
</div>

### 演習: ファンキーにいこうぜ

すべてのモナドはファンクタでもある。
既にある`flatMap`と`pure`を利用して、すべてのモナドに対し同じ方法で`map`を定義することができる:

```tut:book:silent
import scala.language.higherKinds

trait Monad[F[_]] {
  def pure[A](a: A): F[A]

  def flatMap[A, B](value: F[A])(func: A => F[B]): F[B]

  def map[A, B](value: F[A])(func: A => B): F[B] =
    ???
}
```

`map`を自分の手で定義してみよ。

<div class="solution">
一目見るとトリッキーに思えるが、型に従えばただ1つの解があることがわかる。
`F[A]`型の`value`が与えられている。できることはただ1つ、`flatMap`を呼び出すことだ:

```tut:book:silent
trait Monad[F[_]] {
  def pure[A](value: A): F[A]

  def flatMap[A, B](value: F[A])(func: A => F[B]): F[B]

  def map[A, B](value: F[A])(func: A => B): F[B] =
    flatMap(value)(a => ???)
}
```

2つ目の引数に渡す`A => F[B]`型の関数が必要だ。
利用できる構成要素は2つある:
`A => B`型の`func`引数、そして`A => F[A]`型の関数`pure`だ。
これらを組み合わせれば、求める解が得られる:

```tut:book:silent
trait Monad[F[_]] {
  def pure[A](value: A): F[A]

  def flatMap[A, B](value: F[A])(func: A => F[B]): F[B]

  def map[A, B](value: F[A])(func: A => B): F[B] =
    flatMap(value)(a => pure(func(a)))
}
```
</div>
