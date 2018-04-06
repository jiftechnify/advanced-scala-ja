### Cats における Traverse

`listTraverse`と`listSequence`メソッドは任意の`Applicative`型を扱うことができるが、`List`という特定の順列型しか利用できない。
型クラスを用いて順列の型を一般化することができる。そして、まさにこれが Cats の`Traverse`なのである。
詳細を省略した定義はこの通りだ:

```scala
package cats

trait Traverse[F[_]] {
  def traverse[G[_]: Applicative, A, B]
      (inputs: F[A])(func: A => G[B]): G[F[B]]

  def sequence[G[_]: Applicative, B]
      (inputs: F[G[B]]): G[F[B]] =
    traverse(inputs)(identity)
}
```

Cats は`List`、`Vector`、`Stream`、`Option`、`Either`、その他の様々な型に対する `Traverse`のインスタンスを提供している。
いつものように、`Traverse.apply`を用いてインスタンスを召喚し、ここまでの節で説明したように`traverse`や`sequence`メソッドを利用できる:

```tut:book:invisible
import scala.concurrent._
import scala.concurrent.duration._
import scala.concurrent.ExecutionContext.Implicits.global

val hostnames = List(
  "alpha.example.com",
  "beta.example.com",
  "gamma.demo.com"
)

def getUptime(hostname: String): Future[Int] =
  Future(hostname.length * 60)
```

```tut:book:silent
import cats.Traverse
import cats.instances.future._ // for Applicative
import cats.instances.list._   // for Traverse

val totalUptime: Future[List[Int]] =
  Traverse[List].traverse(hostnames)(getUptime)
```

```tut:book
Await.result(totalUptime, 1.second)
```

```tut:book:silent
val numbers = List(Future(1), Future(2), Future(3))

val numbers2: Future[List[Int]] =
  Traverse[List].sequence(numbers)
```

```tut:book
Await.result(numbers2, 1.second)
```

これらのメソッドの構文バージョンもあり、[`cats.syntax.traverse`][cats.syntax.traverse]からインポートできる:

```tut:book:silent
import cats.syntax.traverse._ // for sequence and traverse
```

```tut:book
Await.result(hostnames.traverse(getUptime), 1.second)
Await.result(numbers.sequence, 1.second)
```

ご覧の通り、このコードは本章の前の方で書いた`foldLeft`によるコードよりもはるかにコンパクトで読みやすいものとなっている!
