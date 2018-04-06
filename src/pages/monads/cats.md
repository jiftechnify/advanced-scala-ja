## Cats におけるモナド

さて、Cats におけるモナドの扱いを見ていこう。
いつものように、型クラス、インスタンス、構文の順に見ていく。

### モナド型クラス {#monad-type-class}

モナドの型クラスは[`cats.Monad`][cats.Monad]だ。
`Monad`は2つの型クラスを継承している:
`flatMap`メソッドを提供する`FlatMap`型クラス、そして`pure`を提供する`Applicative`型クラスだ。
`Applicative`は`Functor`も継承しているので、先程の演習で見たように、すべての`Monad`は`map`メソッドを持つ。
`Applicative`については、[@sec:applicatives]章で詳しく見ていく。

以下は`pure`、`flatMap`、`map`を直接利用する例である:

```tut:book:silent
import cats.Monad
import cats.instances.option._ // for Monad
import cats.instances.list._   // for Monad
```

```tut:book
val opt1 = Monad[Option].pure(3)
val opt2 = Monad[Option].flatMap(opt1)(a => Some(a + 2))
val opt3 = Monad[Option].map(opt2)(a => 100 * a)

val list1 = Monad[List].pure(3)
val list2 = Monad[List].
  flatMap(List(1, 2, 3))(a => List(a, a * 10))
val list3 = Monad[List].map(list2)(a => a + 123)
```

`Monad`は他にも、`Functor`が持つすべてのメソッドを含む、多くのメソッドを持つ。
詳しい情報については、[scaladoc][cats.Monad]を参照してほしい。

### 組み込みのインスタンス

Cats は標準ライブラリにあるすべてのモナド(`Option`、`List`、`Vector`など)に対するインスタンスを提供している。これらのインスタンスは[`cats.instances`][cats.instances]にある:

```tut:book:silent
import cats.instances.option._ // for Monad
```

```tut:book
Monad[Option].flatMap(Option(1))(a => Option(a*2))
```

```tut:book:silent
import cats.instances.list._ // for Monad
```

```tut:book
Monad[List].flatMap(List(1, 2, 3))(a => List(a, a*10))
```

```tut:book:silent
import cats.instances.vector._ // for Monad
```

```tut:book
Monad[Vector].flatMap(Vector(1, 2, 3))(a => Vector(a, a*10))
```

Cats は`Future`に対する`Monad`インスタンスも提供している。
`Future`クラスそれ自身のメソッドとは異なり、このモナドインスタンスにおける`pure`や`flatMap`は暗黙の`ExecutionContext`引数をとらない(これは`Monad`トレイトにおけるメソッド定義ががこの引数を持たないためである)。
これに対処するために、`Future`の`Monad`を召喚する際 Cats は`ExecutionContext`がスコープ内にあることを要求する:

```tut:book:silent
import cats.instances.future._ // for Monad
import scala.concurrent._
import scala.concurrent.duration._
```

```tut:book:fail
val fm = Monad[Future]
```

`ExecutionContext`をスコープの中に持ちこむことで、インスタンスを召喚するのに必要な暗黙値の解決がうまくいくようになる:

```tut:book:silent
import scala.concurrent.ExecutionContext.Implicits.global
```

```tut:book
val fm = Monad[Future]
```

この`Monad`のインスタンスは、捕捉した`ExecutionContext`を続く`pure`や`flatMap`の呼び出しのために利用する:

```tut:book:silent
val future = fm.flatMap(fm.pure(1))(x => fm.pure(x + 2))
```

```tut:book
Await.result(future, 1.second)
```

これらに加えて、Cats は標準ライブラリにない多くの新しいモナドを提供している。
そのうちいくつかについては、このあとすぐに説明する。

### モナドの構文

モナドのための構文は3つの場所にある:

 - [`cats.syntax.flatMap`][cats.syntax.flatMap]
   `flatMap`の構文を提供する
 - [`cats.syntax.functor`][cats.syntax.functor]
   `map`の構文を提供する
 - [`cats.syntax.applicative`][cats.syntax.applicative]
   `pure`の構文を提供する

実用上は[`cats.implicits`][cats.implicits]からすべてを一度にインポートしたほうが楽であることが多い。
しかし本書では、利用しているものをはっきりさせるために個別のインポートを用いる。

`pure`を用いてモナド値を生成することができる。
多くの場合、必要な型のモナドインスタンスを明確に示すために型パラメータを指定する必要がある。

```tut.book.silent
import cats.instances.option._   // for Monad
import cats.instances.list._     // for Monad
import cats.syntax.applicative._ // for pure
```

```tut:book
1.pure[Option]
1.pure[List]
```

`Option`や`List`のようなScala 標準のモナドの、`flatMap`や`map`を直接利用した際の動作を実演するのは難しい。これは、標準のモナドがこれらのメソッドを明示的に定義しているためである。
代わりに、ユーザが指定したモナドに包まれた値の上で計算を行う、ジェネリックな関数を書いていくことにする:

```tut:book:silent
import cats.Monad
import cats.syntax.functor._ // for map
import cats.syntax.flatMap._ // for flatMap
import scala.language.higherKinds

def sumSquare[F[_]: Monad](a: F[Int], b: F[Int]): F[Int] =
  a.flatMap(x => b.map(y => x*x + y*y))

import cats.instances.option._ // for Monad
import cats.instances.list._   // for Monad
```

```tut:book
sumSquare(Option(3), Option(4))
sumSquare(List(1, 2, 3), List(4, 5))
```

このコードを for 内包表記を使って書き直すこともできる。
コンパイラは、内包表記を`flatMap`と`map`を用いて書き換え、利用する`Monad`に合った正しい暗黙の変換を挿入することで、「正しいこと」をする:

```tut:book:silent
def sumSquare[F[_]: Monad](a: F[Int], b: F[Int]): F[Int] =
  for {
    x <- a
    y <- b
  } yield x*x + y*y
```

```tut:book
sumSquare(Option(3), Option(4))
sumSquare(List(1, 2, 3), List(4, 5))
```

以上が、Cats におけるモナドの、一般概念として知っておく必要のあることのすべてだ。
さて、Scala 標準ライブラリでは見たことのない、いくつかの便利なモナドのインスタンスを見ていくことにしよう。
