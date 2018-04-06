# 事例: 非同期処理コードのテスト {#sec:case-studies:testing}

まず、直接的な事例から始める:
非同期処理を行うコードを同期的に変えることで、ユニットテストを単純化する方法についてだ。

いくつかのサーバの稼働時間を計測する[@sec:foldable-traverse]章の例に戻ろう。
このコードをより完全な構造へと肉付けしていく。
これには2つの構成要素が含まれることになる。
1つ目は、リモートサーバからその稼働時間を取得する`UptimeClient`だ:

```tut:book:silent
import scala.concurrent.Future

trait UptimeClient {
  def getUptime(hostname: String): Future[Int]
}
```

また、サーバのリストを管理し、それらの稼働時間の合計を取得できるようにする`UpdateService`も必要だろう:

```tut:book:silent
import cats.instances.future._ // for Applicative
import cats.instances.list._   // for Traverse
import cats.syntax.traverse._  // for traverse
import scala.concurrent.ExecutionContext.Implicits.global

class UptimeService(client: UptimeClient) {
  def getTotalUptime(hostnames: List[String]): Future[Int] =
    hostnames.traverse(client.getUptime).map(_.sum)
}
```

`UptimeClient`をトレイトとしてモデル化したのは、ユニットテストの際にそれをスタブにしようと考えているからだ。
例えば、実際のサーバを呼び出さず、代わりにダミーのデータを提供するようなテストクライアントを書くことができる:

```tut:book:silent
class TestUptimeClient(hosts: Map[String, Int]) extends UptimeClient {
  def getUptime(hostname: String): Future[Int] =
    Future.successful(hosts.getOrElse(hostname, 0))
}
```

さて、`UptimeService`に対するユニットテストを書いているとしよう。
実際にどこから稼働時間を取得しているかを考えずに、稼働時間の合計値を計算する機能をテストしたい。
例えば:

```tut:book:fail
def testTotalUptime() = {
  val hosts    = Map("host1" -> 10, "host2" -> 6)
  val client   = new TestUptimeClient(hosts)
  val service  = new UptimeService(client)
  val actual   = service.getTotalUptime(hosts.keys.toList)
  val expected = hosts.values.sum
  assert(actual == expected)
}
```

このコードはコンパイルを通らない。なぜなら、我々は古典的な間違いを犯しているからだ[^warnings]。
このアプリケーションのコードが非同期的であることを忘れていた。
`actual`の結果は`Future[Int]`型なのに対し、`expected`の結果は`Int`型である。
これらを直接比べることはできない!

[^warnings]: 実際には、これは **警告** でありエラーではない。
ここでは、`scalac`の`-Xfatal-warnings`フラグを利用しているため、警告がエラーに昇格されている。

この問題を解決するにはいくつかの方法がある。
非同期性に対応させるために、テストコードを書き換えることもできる。
しかし、もうひとつの代替策がある。
修正することなくテストが動作するように、サービスのコードを同期的なものに変換しよう!

## 型コンストラクタの抽象化

2つのバージョンの`UptimeClient`を実装する必要がある:
ひとつは本番で利用する非同期版、もうひとつはユニットテストで利用する同期版だ:

```scala
trait RealUptimeClient extends UptimeClient {
  def getUptime(hostname: String): Future[Int]
}

trait TestUptimeClient extends UptimeClient {
  def getUptime(hostname: String): Int
}
```

問題は、`UptimeClient`の抽象メソッドの型をどうするかだ。
`Future[Int]`と`Int`の間で抽象化を行わなければならない:

```scala
trait UptimeClient {
  def getUptime(hostname: String): ???
}
```

はじめは難しく見えるだろう。
それぞれの型の`Int`の部分を残しつつ、テストコードでは`Future`の部分を「投げ捨てて」しまいたい。
幸い、Cats は **恒等型** `Id`という解決策を提供している。これは[@sec:monads:identity]節で見たものだ。
`Id`は、型の意味を変えることなく、それを型コンストラクタの中に「包む」ことを可能にする:

```scala
package Cats

type Id[A] = A
```

`Id`は`UptimeClient`の返り値の型を抽象化することを可能にしてくれる。
さあ、これを実装してみよう:

- 型コンストラクタ`F[_]`を型パラメータとして受け取るような、`UptimeClient`のトレイと定義を書け。

- これを`RealUptimeClient`と`TestUptimeClient`の2つのトレイトで継承し、
`F`をそれぞれ`Future`と`Id`に束縛せよ。

- コンパイルが通るように、それぞれの`getUptime`のメソッドのシグネチャを書け。

<div class="solution">
定義は次のようになる:

```tut:book:silent
import scala.language.higherKinds
import cats.Id

trait UptimeClient[F[_]] {
  def getUptime(hostname: String): F[Int]
}

trait RealUptimeClient extends UptimeClient[Future] {
  def getUptime(hostname: String): Future[Int]
}

trait TestUptimeClient extends UptimeClient[Id] {
  def getUptime(hostname: String): Id[Int]
}
```

`Id[A]`は`A`の単なる別名なので、`TestUptimeClient`の中でそれを`Id[Int]`と呼ぶ必要はないということに注意してほしい。代わりに、単に`Int`と書ける:

```tut:book:silent
trait TestUptimeClient extends UptimeClient[Id] {
  def getUptime(hostname: String): Int
}
```

もちろん、技術的にいえば`getUptime`を`RealUptimeClient`や`TestUptimeClient`で再宣言する必要はない。
しかし、すべてを書き下すことは、このテクニックを理解する助けとなる。
</div>

これで、前のように`Map[String, Int]`に基づき、`TestUptimeClient`の定義を具体的に書けるようになったはずだ。

<div class="solution">
最終的なコードは、もはや`Future.successful`を呼び出す必要はないという点を除き、最初の`TestUptimeClient`の実装に似通っている:

```tut:book:silent
object wrapper {
  class TestUptimeClient(hosts: Map[String, Int])
    extends UptimeClient[Id] {
    def getUptime(hostname: String): Int =
      hosts.getOrElse(hostname, 0)
  }
}; import wrapper._
```
</div>

## モナドの抽象化

`UptimeService`に注目を移そう。
2つの型の`UptimeClient`の間で抽象化を行うために、これを書き換える必要がある。
これを2段階で行っていく:
まずクラスとメソッドのシグネチャを書き換え、次にメソッドの本体を書き換える。
まずメソッドシグネチャから始める:

- `getTotalUptime`の本体をコメントアウトせよ
  (すべてがコンパイルを通るように、それを`???`に置き換えよ)。

- `UptimeService`に`F[_]`という型パラメータを追加し、それを`UptimeClient`に渡すようにせよ。

<div class="solution">
コードは次のようになるはずだ:

```tut:book:silent
class UptimeService[F[_]](client: UptimeClient[F]) {
  def getTotalUptime(hostnames: List[String]): F[Int] =
    ???
    // hostnames.traverse(client.getUptime).map(_.sum)
}
```
</div>

ここで、コメントアウトした`getTotalUptime`の本体を戻そう。
次のようなコンパイルエラーが発生するだろう:

```scala
// <console>:28: error: could not find implicit value for
//               evidence parameter of type cats.Applicative[F]
//            hostnames.traverse(client.getUptime).map(_.sum)
//                              ^
```

ここでの問題は、`traverse`が`Applicative`値を持つ値の順列の上でしか動作しないことだ。
元々のコードでは`List[Future[Int]]`をトラバースしていた。
`Future`にはアプリカティブのインスタンスがあるので、正しく動作した。
今のバージョンでは、`List[F[Int]]`をトラバースすることになる。
`F`が`Applicative`のインスタンスを持つことをコンパイラに **証明** してみせなければならない。
`UptimeService`に、暗黙のコンストラクタ引数を追加し、これを行え。

<div class="solution">
これは暗黙の引数として書くことができる:

```tut:book:silent
import cats.Applicative
import cats.syntax.functor._ // for map
```

```tut:book:silent
object wrapper {
  class UptimeService[F[_]](client: UptimeClient[F])
      (implicit a: Applicative[F]) {

    def getTotalUptime(hostnames: List[String]): F[Int] =
      hostnames.traverse(client.getUptime).map(_.sum)
  }
}; import wrapper._
```

または、より簡潔に、コンテキスト境界でも書ける:

```tut:book:silent
object wrapper {
  class UptimeService[F[_]: Applicative]
      (client: UptimeClient[F]) {

    def getTotalUptime(hostnames: List[String]): F[Int] =
      hostnames.traverse(client.getUptime).map(_.sum)
  }
}; import wrapper._
```

`cats.Applicative`と同時に`cats.syntax.functor`をインポートする必要があることに注意してほしい。
これは、`future.map`の代わりに、暗黙の`Functor`引数を必要とする Cats の拡張メソッドを利用するように変更したためである。
</div>

最後に、ユニットテストに注目を移そう。
テストコードは、少しも変更することなく意図通りに動作するようになった。
`TestUptimeClient`のインスタンスを生成し、`UptimeService`に包めばいい。
これによって`F`は`Id`に束縛され、残りのコードは同期的に動作するようになる。モナドやアプリカティブのことを心配する必要はない:

```tut:book:invisible:reset
import cats.{Id, Applicative}
import cats.instances.list._  // for Traverse
import cats.syntax.functor._  // for map
import cats.syntax.traverse._ // for traverse
import scala.concurrent.Future
import scala.language.higherKinds

object wrapper {
  trait UptimeClient[F[_]] {
    def getUptime(hostname: String): F[Int]
  }

  trait RealUptimeClient extends UptimeClient[Future]

  class TestUptimeClient(hosts: Map[String, Int])
      extends UptimeClient[Id] {
    def getUptime(hostname: String): Int =
      hosts.getOrElse(hostname, 0)
    }

  class UptimeService[F[_]: Applicative]
      (client: UptimeClient[F]) {

    def getTotalUptime(hostnames: List[String]): F[Int] =
      hostnames.traverse(client.getUptime).map(_.sum)
  }
}; import wrapper._
```

```tut:book:silent
def testTotalUptime() = {
  val hosts    = Map("host1" -> 10, "host2" -> 6)
  val client   = new TestUptimeClient(hosts)
  val service  = new UptimeService(client)
  val actual   = service.getTotalUptime(hosts.keys.toList)
  val expected = hosts.values.sum
  assert(actual == expected)
}

testTotalUptime()
```

## まとめ

この事例は、Cats を用いてどのように異なる計算シナリオを抽象化すればよいかを示している。
同期的なコードと非同期的なコードの間で抽象化を行うために、`Applicative`型クラスを利用した。
関数的な抽象化によって、実装の詳細について考えることなく、行いたい計算の連鎖の種類を指定することが可能となる。

図[@fig:applicative:hierarchy]では、まさにこのような種類の抽象化を行うために作られた、計算を表現する型クラスの「スタック」を示した。
`Functor`、`Applicative`、`Monad`、そして`Traverse`のような型クラスは、変換、綴じ合わせ(zipping)、逐次計算、そして反復計算といったパターンの、抽象的な実装を提供する。
これらの型の上の数学的な法則が、数々のセマンティクスが協調して動作することを保証する。

この事例で`Applicative`を利用したのは、これが必要とされる最低限の能力を持つ型クラスであったためだ。
`flatMap`が必要だったならば、`Applicative`を`Monad`に取り替えていただろう。
様々な順列の型を抽象化する必要があったならば、`Traverse`を利用していただろう。
成功する計算と同様に失敗をモデル化する助けとなる`ApplicativeError`や`MonadError`のような型クラスもある。

さて、もっと興味深いものを作るのに型クラスが助けとなってくれるような、より複雑な事例に移ろう:
並列処理のための、 map-reduce スタイルのフレームワークだ。
