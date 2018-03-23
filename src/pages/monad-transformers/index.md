# モナド変換子 {#sec:monad-transformers}

モナドは[`ブリトーのようなもの`][link-monads-burritos]だ。これが意味するところは、一度その味を気に入ったら、いつの間にか何度も何度も食べてしまうということだ。
これには問題がつきものだ。
ブリトーがお腹を膨らますのと同じように、モナドはネストした for 内包表記によってコードベースを膨張させうる。

いま、データベースとやりとりしていると想像してみよう。
あるユーザのレコードを探し出したいとする。
ユーザは存在するかもしれないし、存在しないかもしれない。そこで、`Option[User]`を返すようにする。
データベースとの通信は様々な理由(ネットワークの問題、認証の問題など)で失敗しうる。そこで、結果は`Either`に包むようにする。
すると、最終結果は`Either[Error, Option[User]]`型になる。

この値を利用するには、`flatMap`の呼び出しをネストしなければならない(for 内包表記の場合も同様である):

```tut:book:invisible
type Error = String

final case class User(id: Long, name: String)

def lookupUser(id: Long): Either[Error, Option[User]] = ???
```

```tut:book:silent
def lookupUserName(id: Long): Either[Error, Option[String]] =
  for {
    optUser <- lookupUser(id)
  } yield {
    for { user <- optUser } yield user.name
  }
```

これはたちまち、非常に退屈なものとなる。

## 演習: モナドの合成

ここでひとつの疑問が浮上する。
2つの任意のモナドが与えられたとき、それを1つのモナドにするためにそれらを組み合わせる方法はないのだろうか?
つまり、モナドは **合成できるのだろうか** ?
コードを書いてみると、すぐに問題にぶつかる:

```tut:book:silent
import cats.Monad
import cats.syntax.applicative._ // for pure
import cats.syntax.flatMap._     // for flatMap
import scala.language.higherKinds
```

```scala
// 仮の例。実際にはコンパイルを通らない
def compose[M1[_]: Monad, M2[_]: Monad] = {
  type Composed[A] = M1[M2[A]]

  new Monad[Composed] {
    def pure[A](a: A): Composed[A] =
      a.pure[M2].pure[M1]

    def flatMap[A, B](fa: Composed[A])
        (f: A => Composed[B]): Composed[B] =
      // 問題発生! flatMapをどう書けばいい?
      ???
  }
}
```

`M1`や`M2`についての何らかの知識なしに、汎用的な`flatMap`の定義を書くことは不可能である。
しかし、どちらかのモナドについて何か分かっていることが **あれば**、多くの場合このコードを完成させることができる。
例えば、上の例の`M2`を`Option`に固定すれば、`flatMap`の定義が明らかになる:

```scala
def flatMap[A, B](fa: Composed[A])
    (f: A => Composed[B]): Composed[B] =
  fa.flatMap(_.fold(None.pure[M])(f))
```

上の定義において`None`を利用していることに注意してほしい---これは汎用的な`Monad`のインターフェイスには現れない、`Option`に固有の概念である。
`Option`を他のモナドと組み合わせるには、この追加の詳細情報が必要なのだ。
同様に、他のモナドに対しても、合成された`flatMap`を書く助けになるような何かがある。
これが、モナド変換子の背景にある考え方だ:
Cats は、様々なモナドを他のモナドと合成するための変換子を定義している。
いくつかの例を見ていこう。

## 変革的な一例

Cats は、多くのモナドに対して`T`という文字で終わる名前の変換子を提供している:
`EitherT`は`Either`を他のモナドと合成し、`OptionT`は`Option`を合成する。以下同様である。

以下に`List`と`Option`を合成するのに`OptionT`を用いる例を示す。
ここでは、`List[Option[A]]`を1つのモナドに変換するのに`OptionT[List, A]`を利用できる(便宜のため、`ListOption[A]`という別名をつけた)。

```tut:book:silent
import cats.data.OptionT

type ListOption[A] = OptionT[List, A]
```

`ListOption`を構成する方法を徹底的に見ていこう:
外側のモナドの型である`List`を、内側のモナドに対する変換子である`OptionT`の型パラメータとして渡している。

`OptionT`コンストラクタ、またはもっと便利な`pure`を用いて`ListOption`のインスタンスを生成することができる:

```tut:book:silent
import cats.Monad
import cats.instances.list._     // for Monad
import cats.syntax.applicative._ // for pure
```

```tut:book
val result1: ListOption[Int] = OptionT(List(Option(10)))

val result2: ListOption[Int] = 32.pure[ListOption]
```

`map`と`flatMap`メソッドは、`List`と`Option`にある対応するメソッドを1つの演算に合成したものとなる:

```tut:book
result1.flatMap { (x: Int) =>
  result2.map { (y: Int) =>
    x + y
  }
}
```

これが、すべてのモナド変換子の基本である。
組み合わされた`map`や`flatMap`メソッドは、再帰的に値を取り出したり、再び値を包んだりする必要なしに、構成要素のモナドの両方を計算の各段階で利用することを可能にする。
さて、APIをさらに詳しく見ていこう。

<div class="callout callout-warning">
**複雑なインポートについて**

上のコード例におけるインポートは、すべてを組み合わせる方法を示唆している。

[`cats.syntax.applicative`][cats.syntax.applicative]をインポートすることで、`pure`構文が使えるようになる。
`pure`は`Applicative[ListOption]`型の型パラメータを要求する。
まだ`Applicative`は見ていないが、すべての`Monad`は`Applicative`でもあるので、今はこの違いを無視できる。

`Applicative[ListOption]`を生成するには、`List`と`OptionT`に対する`Applicative`のインスタンスは必要である。
`OptionT`は Cats のデータ型なので、そのインスタンスはコンパニオンオブジェクトにある。
`List`に対するインスタンスは[`cats.instances.list`][cats.instances.list]から持ってくる。

ここで[`cats.syntax.functor`][cats.syntax.functor]や[`cats.syntax.flatMap`][cats.syntax.flatMap]をインポートしていないことに注意してほしい。
これは、`OptionT`がそれ自身の明示的な`map`や`flatMap`メソッドを持つ具体的なデータ型であるためだ。
この構文をインポートしたとしても問題は発生しない---コンパイラは明示的なメソッドを優先するので、それを無視するだろう。

このような馬鹿げたことをしなければならないのは、[`cats.implicits`][cats.implicits]という万能な Cats のインポートを利用することを頑なに拒んでいるためだということを思い出してほしい。
このインポートを利用すれば、必要なインスタンスと構文のすべてがスコープの中に入り、すべてがうまくいく。
</div>

## Cats におけるモナド変換子

それぞれのモナド変換子は、[`cats.data`][cats.data]の中に定義されているデータ型で、新しいモナドを生成するために、積み重なったモナドを包むことを可能にする。
`Monad`型クラスによって構成されたモナドを利用できる。
モナド変換子を理解するのに説明しなければならない概念は以下の通りだ:

- 利用できる変換子クラス
- 変換子を使ってモナドのスタックを構成する方法
- モナドスタックのインスタンスを構築する方法
- 包まれたモナドにアクセスするするために、モナドスタックを分解する方法

### モナド変換子のクラス

慣例に従い、Cats において`Foo`というモナドは`FooT`と呼ばれる変換子クラスを持つ。
実際のところ、Cats にある多くのモナドはモナド変換子と`Id`モナドを組み合わせることで定義されている。
具体的に、利用できるインスタンスのうちいくつかを挙げる:

- `Option`に対応する [`cats.data.OptionT`][cats.data.OptionT]
- `Either`に対応する [`cats.data.EitherT`][cats.data.EitherT]
- `Reader`に対応する [`cats.data.ReaderT`][cats.data.ReaderT]
- `Writer`に対応する [`cats.data.WriterT`][cats.data.WriterT]
- `State`に対応する [`cats.data.StateT`][cats.data.StateT]
- [`Id`][cats.Id]モナドに対応する [`cats.data.IdT`][cats.data.IdT]

<div class="callout callout-info">
**クライスリ射**

[@sec:monads:reader]節で、`Reader`モナドは、 Cats において[`cats.data.Kleisli`][cats.data.Kleisli]という形で表現されている、「クライスリ射」というより一般的な概念の特別な場合であることに触れた。

実は、`Kleisli`と`ReaderT`は同じものである!
これが前の章で`Reader`を生成したときにコンソールに`Kleisli`が現れた理由である。
</div>

### モナドスタックを構築する

これらのモナド変換子はすべて同じ規則に従う。
変換子自体はスタックの **内側** のモナドを表し、1つ目の型パラメータは外側のモナドを指定する。
残りの型パラメータは、対応するモナドを形成するのに使う型である。

例えば、上の`ListOption`型は`OptionT[List, A]`の別名だが、その結果は実質`List[Option[A]]`である。
言い換えれば、モナドスタックを構築するとき、内側と外側が裏返る:

```tut:book
type ListOption[A] = OptionT[List, A]
```

多くのモナドインスタンスとすべての変換子は、少なくとも2つの型パラメータを持つので、しばしば中間段階の型に対するいくつかの型エイリアスを定義しなければならない。

例えば、`Option`を`Either`で包みたいとしよう。
`Option`は最も内側の型なので、`OptionT`モナド変換子を用いれば良いだろう。
`Either`を1つ目の型パラメータとして利用する必要があるが、`Either`それ自体は2つの型パラメータを持つ一方で、モナドは1つしか型パラメータを持たない。
そこで、型コンストラクタを正しい形に変換するために型エイリアスが必要となる:

```tut:book:silent
// Eitherの別名として、1つの型パラメータをとる型コンストラクタを定義
type ErrorOr[A] = Either[String, A]

// OptionT を用いて最終的なモナドスタックを構築
type ErrorOrOption[A] = OptionT[ErrorOr, A]
```

`ListOption`と同様に、`ErrorOrOption`もモナドである。
いつものように、`pure`、`map`、`flatMap`をインスタンスの生成・変換のために利用できる:

```tut:book:silent
import cats.instances.either._ // for Monad
```

```tut:book
val a = 10.pure[ErrorOrOption]
val b = 32.pure[ErrorOrOption]

val c = a.flatMap(x => b.map(y => x + y))
```

3つ以上のモナドを積み上げようとすると、事態はより混乱する。

例として、`Option`の`Either`の`Future`を作ってみよう。
今回も、`Future`の`EitherT`の`OptionT`のように内側と外側を入れ替えながらこれを構築する。
しかし、`EitherT`は3つの型パラメータをとるので、これを1行で定義することはできない:

```scala
case class EitherT[F[_], E, A](stack: F[Either[E, A]]) {
  // ...
}
```

3つの型パラメータは次のようなものである:

- `F[_]`: スタックの外側のモナド(`Either`は内側)
- `E`: `Either`のエラーの型
- `A`: `Either`の結果の型

ここでは`Future`と`Error`を固定し、`A`を可変のまま残す`EitherT`のエイリアスを作成する:

```tut:book:silent
import scala.concurrent.Future
import cats.data.{EitherT, OptionT}

type FutureEither[A] = EitherT[Future, String, A]

type FutureEitherOption[A] = OptionT[FutureEither, A]
```

このマンモスのように巨大なスタックは3つのモナドを合成したものであり、`map`と`flatMap`メソッドは3つの抽象化レイヤに横断してはたらく:

```tut:book:silent
import cats.instances.future._ // for Monad
import scala.concurrent.Await
import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.duration._
```

```tut:book:silent
val futureEitherOr: FutureEitherOption[Int] =
  for {
    a <- 10.pure[FutureEitherOption]
    b <- 32.pure[FutureEitherOption]
  } yield a + b
```

<div class="callout callout-warning">
*Kind Projecter*

モナドスタックを構築する際、頻繁に複数の型エイリアスを定義していることに気づいたら、[Kind Projecter][link-kind-projector]というコンパイラプラグインを利用するとよい。
Kind Projector は、Scala の型構文を強化し、部分適用された型コンストラクタを簡単に定義できるようにしてくれる。
例えば:

```tut:book
import cats.instances.option._ // for Monad

123.pure[EitherT[Option, String, ?]]
```

Kind Projector によってすべての型宣言を1行にまで単純化することはできないが、コードを読みやすく保つのに必要な、中間的な型宣言の数を削減することができる。
</div>

### インスタンスの生成と値の取り出し

上で見たように、適切なモナド変換子の`apply`メソッド、またはいつもの`pure`構文によって変換後のモナドスタックの値を生成できる[^eithert-monad-error]:

```tut:book
// apply による生成
val errorStack1 = OptionT[ErrorOr, Int](Right(Some(10)))

// pure による生成
val errorStack2 = 32.pure[ErrorOrOption]
```

[^eithert-monad-error]: Cats は`EitherT`に対する`MonadError`のインスタンスを提供し、`pure`と同じように`raiseError`を使ってインスタンスを生成できるようにしている。

モナド変換子のスタックを仕上げたら、`value`メソッドを利用してそれから値を取り出すことができる。
これは逆変換されたスタックを返す。
あとは、いつもの方法で個別のモナドを操作できる:

```tut:book
// 逆変換されたモナドスタックを取り出す
errorStack1.value

// スタックの中のEitherを変換する
errorStack2.value.map(_.getOrElse(-1))
```

それぞれの`value`の呼び出しは、1つのモナド変換子から値を取り出す。
大きなスタックから完全に値を取り出すには、`value`を2回以上呼び出す必要があるだろう。
例えば、上の`FutureEitherOption`スタックを`Await`するには、`value`を2回呼び出さなければならない:

```tut:book
futureEitherOr

val intermediate = futureEitherOr.value

val stack = intermediate.value

Await.result(stack, 1.second)
```

### 組み込みのインスタンス

Cats の多くのモナドは、対応する変換子と`Id`モナドによって定義されている。
これによってモナドとモナド変換子のAPIが同一であるということを再確認できる。
`Reader`、`Writer`、`State`はすべてこの方法で定義されている:

```scala
type Reader[E, A] = ReaderT[Id, E, A] // = Kleisli[Id, E, A]
type Writer[W, A] = WriterT[Id, W, A]
type State[S, A]  = StateT[Id, S, A]
```

他の場合では、モナド変換子は対応するモナドとは個別に定義されている。
この場合、モナド変換子のメソッドは対応するモナドのメソッドに似ていることが多い。
例えば、`OptionT`は`getOrElse`を、`EitherT`は`fold`、`bimap`、`swap`やその他の有用なメソッドを定義している。

### 利用パターン

モナド変換子を幅広く利用するのは、時に難しい。それは、変換子がモナドをあらかじめ定められた方法で融合させるためである。
注意深く考慮しなければ、別々の文脈において値を操作するために、結局別々の方法で値を取り出したり包みなおしたりする必要のあるモナドが出来上がる。

この問題には複数の方法で対処できる。
1つのアプローチとしては、ひとつの「スーパースタック」を作り、コードベースのすべての場所でそれを使い通すという方法が考えられる。
この方法は、コードが単純で、本質的に単調な場合はうまくいく。
例えば、web アプリケーションにおいて、すべてのリクエストハンドラは非同期で処理を行い、すべての失敗は 一定の範囲の HTTP エラーコードを返す、と決めることができる。
この場合、エラーを表現する独自の ADT を設計すれば、`Future`と`Either`の組み合わせをコードの至るところで利用することができる:

```tut:book:silent
sealed abstract class HttpError
final case class NotFound(item: String) extends HttpError
final case class BadRequest(msg: String) extends HttpError
// ...

type FutureEither[A] = EitherT[Future, HttpError, A]
```

この「スーパースタック」によるアプローチは、文脈によって意味を成すモナドスタックは変わるような、より大きく、より不均質なコードベースではうまくいかなくなる。
このような場合により有意義な、もうひとつのデザインパターンは、モナド変換子を「グルーコード(glue code)」として局所的に利用するというものである。
逆変換されたスタックをモジュールの境界にさらけ出し、局所的にモナドスタックを用いて操作して、その結果を返す前に逆変換する。
この方法では、それぞれのモジュールのコードが、どの変換子を使うかを個別に決めることができる:

```tut:book:silent
import cats.data.Writer

type Logged[A] = Writer[List[String], A]

// メソッドはいつも逆変換されたモナドスタックを返す:
def parseNumber(str: String): Logged[Option[Int]] =
  util.Try(str.toInt).toOption match {
    case Some(num) => Writer(List(s"Read $str"), Some(num))
    case None      => Writer(List(s"Failed on $str"), None)
  }

// スタックの消費者は、合成を単純化するため局所的にモナド変換子を用いる:
def addAll(a: String, b: String, c: String): Logged[Option[Int]] = {
  import cats.data.OptionT

  val result = for {
    a <- OptionT(parseNumber(a))
    b <- OptionT(parseNumber(b))
    c <- OptionT(parseNumber(c))
  } yield a + b + c

  result.value
}
```

```tut:book
// このアプローチは、ユーザが他のコードでOptionTを使うことを強制しない
val result1 = addAll("1", "2", "3")
val result2 = addAll("1", "a", "3")
```

残念なことに、モナド変換子を扱う万能なアプローチは存在しない。
ベストなアプローチは、チームの大きさと経験、コードベースの複雑さなどの要因による。
実際にやってみて、同僚からフィードバックを集めることで、モナド変換子がぴったりかどうかを判断しなければならない。

## 演習: モナド、トランスフォーム、ロールアウト

変装したロボットとしてよく知られているオートボットは、戦いの間にチームメイトのパワーレベルを知るために、しばしばメッセージを送っている。
これは、作戦を練って必殺技を繰り出す助けとなる。
メッセージの送信メソッドは次のようになっている:

```scala
def getPowerLevel(autobot: String): Response[Int] =
  ???
```

地球の粘性の高い大気中では伝送に時間がかかるうえ、衛星の故障や憎きデストロン[^transformers]による破壊活動のせいで、メッセージが失われる可能性もある。
そのため`Response`は次のようなモナドスタックとして表現される:

```tut:book
type Response[A] = Future[Either[String, A]]
```

[^transformers]: オートボットのニューラルネットが Scala で実装されているという事実は、周知の通りである。
デストロンのブレーンは、もちろん動的型付けだ。

コンボイ(Optimus Prime)は、ニューラルマトリックスの上で for 内包表記をネストするのに飽き飽きしている。
`Response`をモナド変換子(トランスフォーマー)を使って書き換えることで、彼を援護せよ。

<div class="solution">
これは比較的シンプルな組み合わせである。
`Future`を外側に、`Either`を内側に置きたいので、`Future`の`EitherT`を利用してスタックを裏返す:

```tut:book:silent
import cats.data.EitherT
import scala.concurrent.Future

type Response[A] = EitherT[Future, String, A]
```
</div>

ここで、仮想的な味方のデータを検索できるように`getPowerLevel`を実装し、このコードをテストせよ。
利用するデータは以下の通り:

```tut:book:silent
val powerLevels = Map(
  "Jazz"      -> 6,
  "Bumblebee" -> 8,
  "Hot Rod"   -> 10
)
```

オートボットが`powerLevels`のマップの中にいなければ、到達できなかったことを報告するエラーメッセージを返すこと。
メッセージに`name`を含めるといいだろう。

<div class="solution">
```tut:book:silent
import cats.instances.future._ // for Monad
import cats.syntax.flatMap._   // for flatMap
import scala.concurrent.ExecutionContext.Implicits.global

type Response[A] = EitherT[Future, String, A]

def getPowerLevel(ally: String): Response[Int] = {
  powerLevels.get(ally) match {
    case Some(avg) => EitherT.right(Future(avg))
    case None      => EitherT.left(Future(s"$ally unreachable"))
  }
}
```
</div>

2体のオートボットは、合計パワーレベルが15より大きければ必殺技を使える。
`canSpecialMove`という、2体の味方の名前を受け取って必殺技が使えるかどうかチェックするメソッドを書け。
どちらかの味方がいない場合は、適切なエラーメッセージとともに失敗するようにせよ:

```tut:book:silent
def canSpecialMove(ally1: String, ally2: String): Response[Boolean] =
  ???
```

<div class="solution">
それぞれの味方にパワーレベルをリクエストし、その結果を`map`と`flatMap`を利用して組み合わせればよい:

```tut:book:silent
def canSpecialMove(ally1: String, ally2: String): Response[Boolean] =
  for {
    power1 <- getPowerLevel(ally1)
    power2 <- getPowerLevel(ally2)
  } yield (power1 + power2) > 15
```
</div>

最後に、2体の味方の名前をとって必殺技を使えるかどうかをメッセージとして出力する`tacticalReport`メソッドを書け:

```tut:book:silent
def tacticalReport(ally1: String, ally2: String): String =
  ???
```

<div class="solution">
モナドスタックを取り出すために`value`メソッドを用い、`Await`と`fold`によって`Future`と`Either`から値を取り出せばよい:

```tut:book:silent
import scala.concurrent.Await
import scala.concurrent.ExecutionContext.Implicits.global
import scala.concurrent.duration._

def tacticalReport(ally1: String, ally2: String): String = {
  val stack = canSpecialMove(ally1, ally2).value

  Await.result(stack, 1.second) match {
    case Left(msg) =>
      s"Comms error: $msg"
    case Right(true) =>
      s"$ally1 and $ally2 are ready to roll out!"
    case Right(false) =>
      s"$ally1 and $ally2 need a recharge."
  }
}
```
</div>

`tacticalReport`は次のように利用できるはずだ:

```tut:book
tacticalReport("Jazz", "Bumblebee")
tacticalReport("Bumblebee", "Hot Rod")
tacticalReport("Jazz", "Ironhide")
```
