## Either

もうひとつ、便利なモナドを見ていこう:
Scala 標準ライブラリの`Either`だ。
Scala 2.11 以前は、`Either`が`map`や`flatMap`メソッドを持っていなかったので、多くの人はそれをモナドとはみなしていなかった。
ところが、Scala 2.12 では、`Either`は **右バイアス** になったのだ。

### 左・右バイアス

Scala 2.11 では、`Either`はデフォルトの`map`や`flatMap`メソッドを持っていなかった。
そのためScala 2.11 の`Either`は for 内包表記で使うには不便なものであった。
各ジェネレータ節に`.right`の呼び出しを挿入する必要があったのだ:

```tut:book:silent
val either1: Either[String, Int] = Right(10)
val either2: Either[String, Int] = Right(32)
```

```tut:book
for {
  a <- either1.right
  b <- either2.right
} yield a + b
```

Scala 2.12 で、`Either`は設計し直された。
モダンな`Either`では、右側が成功の場合を表すことに決め、直接`map`と`flatMap`を呼び出せるようになった。
これで for 内包表記がより快適なものとなった:

```tut:book
for {
  a <- either1
  b <- either2
} yield a + b
```

Cats は`cats.syntax.either`インポートによってこの振る舞いを Scala 2.11 以前にも逆輸入しており、すべてのサポートされる Scala バージョンで右バイアスな`Either`を利用できるようになる。
Scala 2.12 以降では、このインポートを取り除いてもいいし、これまでのコードを壊さないようそのままにしておいてもいい:

```tut:book:silent
import cats.syntax.either._ // for map and flatMap

for {
  a <- either1
  b <- either2
} yield a + b
```

### インスタンスの生成

`Left`や`Right`のインスタンスを直接生成できるだけでなく、[`cats.syntax.either`][cats.syntax.either]にある`asLeft`・`asRight`拡張メソッドをインポートして利用することもできる:

```tut:book:silent
import cats.syntax.either._ // for asRight
```

```tut:book
val a = 3.asRight[String]
val b = 4.asRight[String]

for {
  x <- a
  y <- b
} yield x*x + y*y
```

これらの「スマートコンストラクタ」は、`Left.apply`や`Right.apply`と比較して`Left`型や`Right`型ではなく`Either`型の値を返すという点で優れている。
これは、以下の例に示すような、過剰な狭小化により引き起こされる型推論のバグを回避する助けとなる:

```tut:book:fail
def countPositive(nums: List[Int]) =
  nums.foldLeft(Right(0)) { (accumulator, num) =>
    if(num > 0) {
      accumulator.map(_ + 1)
    } else {
      Left("Negative. Stopping!")
    }
  }
```

このコードは2つの理由でコンパイルに失敗する:

1. コンパイラは蓄積変数(accumulator)の型を`Either`ではなく`Right`と推論する
2. `Right.apply`では型パラメータを指定できないので、左の型パラメータを`Nothing`と推論する

代わりに`asRight`を用いることで、これらの問題の両方を回避することができる。
`asRight`の返り値は`Either`型を持ち、ただ1つの型パラメータによって型を完全に指定することができる:

```tut:book:silent
def countPositive(nums: List[Int]) =
  nums.foldLeft(0.asRight[String]) { (accumulator, num) =>
    if(num > 0) {
      accumulator.map(_ + 1)
    } else {
      Left("Negative. Stopping!")
    }
  }
```

```tut:book
countPositive(List(1, 2, 3))
countPositive(List(1, -2, 3))
```

`cats.syntax.either`は、`Either`のコンパニオンオブジェクトにいくつかの便利な拡張メソッドを追加する。
`catchOnly`メソッドと`catchNonFatal`メソッドは、`Exception`を`Either`のインスタンスとして捕捉するのに使える。

```tut:book
Either.catchOnly[NumberFormatException]("foo".toInt)
Either.catchNonFatal(sys.error("Badness"))
```

他のデータ型から`Either`を生成するためのメソッドもある:

```tut:book
Either.fromTry(scala.util.Try("foo".toInt))
Either.fromOption[String, Int](None, "Badness")
```

### Either の変換

`cats.syntax.either`は、`Either`のインスタンスにもいくつかの便利なメソッドを追加する。
右側の値を取り出すかデフォルト値を返す`orElse`メソッドと`getOrElse`メソッドを利用できる:

```tut:book:silent
import cats.syntax.either._
```

```tut:book
"Error".asLeft[Int].getOrElse(0)
"Error".asLeft[Int].orElse(2.asRight[String])
```

`ensure`メソッドは、右側の値がある条件を満たすことを確認する機能をもたらす:

```tut:book
-1.asRight[String].ensure("Must be non-negative!")(_ > 0)
```

`recover`メソッドと`recoverWith`メソッドは、`Future`にある同じ名前のメソッドと似たエラー処理機能を提供する:

```tut:book
"error".asLeft[Int].recover {
  case str: String => -1
}

"error".asLeft[Int].recoverWith {
  case str: String => Right(-1)
}
```

`map`を補う`leftMap`と`bimap`メソッドもある:

```tut:book
"foo".asLeft[Int].leftMap(_.reverse)
6.asRight[String].bimap(_.reverse, _ * 7)
"bar".asLeft[Int].bimap(_.reverse, _ * 7)
```

`swap`メソッドによって、左と右の値を入れ替えることができる:

```tut.book
123.asRight[String]
123.asRight[String].swap
```

最後に、Cats は`toOption`、`toList`、`toTry`、`toValidated`など、多数の変換メソッドを追加している。

## エラー処理

`Either`の典型的な利用用途は、フェイルファストなエラー処理の実装である。
いつものように、`flatMap`を使って計算を連鎖させる。
ある計算が失敗したら、残りの計算は実行されない:

```tut:book
for {
  a <- 1.asRight[String]
  b <- 0.asRight[String]
  c <- if(b == 0) "DIV0".asLeft[Int]
       else (a / b).asRight[String]
} yield c * 100
```

`Either`をエラー処理に使う際は、エラーを表すのにどんな型を用いるかを決める必要がある。
このために`Throwable`を使うこともできるだろう:

```tut:book:silent
type Result[A] = Either[Throwable, A]
```

これは`scala.util.Try`と似たセマンティクスを持つ。
しかし、`Throwable`型では範囲があまりにも広すぎるという問題がある。
発生したエラーがどんな種類のエラーか、(ほとんど)分からないのだ。

もう1つのアプローチとして、プログラムの中で発生しうるエラーを表現する代数的データ型を定義することが考えられる:

```tut:book:silent
object wrapper {
  sealed trait LoginError extends Product with Serializable

  final case class UserNotFound(username: String)
    extends LoginError

  final case classs PasswordIncorrect(username: String)
    extends LoginError

  case object UnexpectedError extends LogoinError
}; import wrapper._
```

```tut:book:silent
case class User(username: String, password: String)

type LoginResult = Either[LoginError, User]
```

このアプローチは、`Throwable`でみたような問題を解決する。
これにより、起きうるエラーの集合と、それ以外の予期しないエラーの集合を分離できる。
また、いかなるパターンマッチにおいても、すべての場合を尽くしているかがチェックされるという安全性も手に入る:

```tut:book:silent
// 型に基づいてエラー処理の振る舞いを選択する
def handleError(error: LogoinError): Unit =
  error match {
    case UserNotFound(u) =>
      println(s"User not found: $u)

    case PasswordIncorrect(u) =>
      println(s"Password incorrect: $u)

    case UnexpectedError =>
      println(s"Unexpected error")
  }
```

```tut:book
val result1: LoginResult = User("dave", "passw0rd").asRight
val result2: LoginResult = UserNotFound("dave").asLeft

result1.fold(handleError, println)
result2.fold(handleError, println)
```

### 演習: 一番いいのを頼む

前の例におけるエラー処理戦略は、どんな目的にも適しているのだろうか?
エラー処理に求められる特徴は、他にも何かないだろうか?

<div class="solution">
これは「答えのない」問題だ。
これはある意味「引っ掛け」問題でもある---答えは、求めるセマンティクスによりけりなのだ。
いくつか考慮すべき点を示そう:

- 大きな処理を行っている際は、エラーからの復帰が重要となる。
  1日いっぱいかかる処理を実行して、最後で失敗を見つけるということがあってほしくはないだろう。

- エラー報告も同じくらい重要だ。
  「何かが」うまく行かなかったということではなく、「何が」うまく行かなかったのかを知る必要があるのだ。

- 最初に遭遇したエラーだけでなく、発生したすべてのエラーを集めたい場合もある。
  典型的な例として、web フォームの入力値検証が挙げられる。
  エラーを一度に1つずつ報告するより、フォームの送信時にすべてのエラーを報告した方が、ユーザの体験はずっと良いものになるだろう。
</div>
