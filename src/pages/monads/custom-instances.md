## 独自のモナドを定義する

3つのメソッドの実装を与えることで、独自の型に対する`Monad`インスタンスを定義できる:
`flatMap`、`pure`、そしてまだ見ぬ`tailRecM`と呼ばれるメソッドだ。
例として、`Option`に対する`Monad`の実装を以下に示す:

```tut:book:silent
import cats.Monad
import scala.annotation.tailrec

val optionMonad = new Monad[Option] {
  def flatMap[A, B](opt: Option[A])
      (fn: A => Option[B]): Option[B] =
    opt flatMap fn

  def pure[A](opt: A): Option[A] =
    Some(opt)

  @tailrec
  def tailRecM[A, B](a: A)
      (fn: A => Option[Either[A, B]]): Option[B] =
    fn(a) match {
      case None           => None
      case Some(Left(a1)) => tailRecM(a1)(fn)
      case Some(Right(b)) => Some(b)
    }
}
```

`tailRecM`メソッドは Cats が `flatMap`のネストした呼び出しで消費するスタック空間の量を節約するために用いる最適化である。
このテクニックは、PureScriptの作者である Phil Freeman の[2015年の論文][link-phil-freeman-tailrecm]に由来する。
このメソッドは、`fn`が`Right`値を返すまで自身を再帰的に呼び出すようにする必要がある。

`tailRecM`を末尾再帰にすることができるならば、Cats は巨大なリストの畳み込み([@sec:foldable]節を参照)のような再帰を多用する状況で、スタック安全性を保証できる。
`tailRecM`を末尾再帰にできないならば、Cats はスタック安全性保証できず、極端な場合`StackOverflowError`という結果に終わる。
Cats におけるすべての組み込みのモナドは、末尾再帰的な`tailRecM`の実装を持つが、独自のモナドに対し`tailRecM`を書くのは、これから見ていくように難しいこともある...

### 演習: モナドでもっと分岐

前章の`Tree`データ型に対する`Monad`インスタンスを書いてみよう。
`Tree`の型定義を再掲する:

```tut:book:silent
object wrapper {
  sealed trait Tree[+A]

  final case class Branch[A](left: Tree[A], right: Tree[A])
    extends Tree[A]

  final case class Leaf[A](value: A) extends Tree[A]

  def branch[A](left: Tree[A], right: Tree[A]): Tree[A] =
    Branch(left, right)

  def leaf[A](value: A): Tree[A] =
    Leaf(value)
}; import wrapper._
```

`Branch`と`Leaf`のインスタンスに対してコードが動作すること、この`Monad`が`Functor`の振る舞いをタダで提供することを確認せよ。

この`Monad`をスコープの中に入れることで、`Tree`に対して直接`flatMap`や`map`を実装しなくても`Tree`が for 内包表記で利用できるようになることを確認せよ。

`tailRecM`を末尾再帰にすることは考えなくてもよい。
そうするのはかなり難しい。
あなたの答えをチェックできるよう、解答には末尾再帰的な実装とそうでない実装の両方を含めた。

<div class="solution">
`flatMap`のコードは`map`のものに似たものとなる。
今回も、木構造を再帰的に下って`func`の結果を新たな`Tree`を構築するのに利用する。

`tailRecM`のコードは、末尾再帰的かどうかにかかわらず、かなり複雑になる。

型に従えば、末尾再帰的でない解答が得られる:

```tut:book:silent
import cats.Monad

implicit val treeMonad = new Monad[Tree] {
  def pure[A](value: A): Tree[A] =
    Leaf(value)

  def flatMap[A, B](tree: Tree[A])
      (func: A => Tree[B]): Tree[B] =
    tree match {
      case Branch(l, r) =>
        Branch(flatMap(l)(func), flatMap(r)(func))
      case Leaf(value)  =>
        func(value)
    }

  def tailRecM[A, B](a: A)
      (func: A => Tree[Either[A, B]]): Tree[B] =
    flatMap(func(a)) {
      case Left(value) =>
        tailRecM(value)(func)
      case Right(value) =>
        Leaf(value)
    }
}
```

以上の解答はこの演習に対する完全に正しい解答である。
ただひとつの欠点は、Cats がスタック安全性を保証できないことだ。

末尾再帰の解答を書くのはもっと難しい。
この解答は Nazarii Bardiuk による[この Stack Overflow の投稿][link-so-tree-tailrecm]を修正したものである。
これは、これから探索するノードの`open`リストと、木を再構成するのに利用する`closed`リストを管理するような、木の明示的な深さ優先探索を含んでいる。

```tut:book:silent
import cats.Monad

implicit val treeMonad = new Monad[Tree] {
  def pure[A](value: A): Tree[A] =
    Leaf(value)

  def flatMap[A, B](tree: Tree[A])
      (func: A => Tree[B]): Tree[B] =
    tree match {
      case Branch(l, r) =>
        Branch(flatMap(l)(func), flatMap(r)(func))
      case Leaf(value)  =>
        func(value)
    }

  def tailRecM[A, B](arg: A)
      (func: A => Tree[Either[A, B]]): Tree[B] = {
    @tailrec
    def loop(
          open: List[Tree[Either[A, B]]],
          closed: List[Tree[B]]): List[Tree[B]] =
      open match {
        case Branch(l, r) :: next =>
          l match {
            case Branch(_, _) =>
              loop(l :: r :: next, closed)
            case Leaf(Left(value)) =>
              loop(func(value) :: r :: next, closed)
            case Leaf(Right(value)) =>
              loop(r :: next, pure(value) :: closed)
          }

        case Leaf(Left(value)) :: next =>
          loop(func(value) :: next, closed)

        case Leaf(Right(value)) :: next =>
          closed match {
            case head :: tail =>
              loop(next, Branch(head, pure(value)) :: tail)
            case Nil =>
              loop(next, pure(value) :: closed)
          }
        case Nil =>
          closed
      }

    loop(List(func(arg)), Nil).head
  }
}
```

どちらの`tailRecM`かにかかわらず、`Tree`の上で`flatMap`や`map`を行うために`Monad`インスタンスをを利用できる:

```tut:book:silent
import cats.syntax.functor._ // for map
import cats.syntax.flatMap._ // for flatMap
```

```tut:book
branch(leaf(100), leaf(200)).
  flatMap(x => branch(leaf(x - 1), leaf(x + 1)))
```

for 内包表記を利用して`Tree`を変換をすることもできる:

We can also transform `Trees` using for comprehensions:

```tut:book
for {
  a <- branch(leaf(100), leaf(200))
  b <- branch(leaf(a - 10), leaf(a + 10))
  c <- branch(leaf(b - 1), leaf(b + 1))
} yield c
```

`Option`のモナドはフェイルファストなセマンティクスを持つ。
`List`のモナドは結合のセマンティクスを持つ。
二分木の`flatMap`が持つセマンティクスは何なのだろうか?
木を構成するそれぞれのノードは、部分木によって置き換えられる可能性を持ち、これは「成長」や「枝分かれ」のような振る舞いを生む。これは2つの軸に沿ったリストの結合のようなものだといえる。
</div>
