## Cats におけるファンクタ

Cats におけるファンクタの実装を見ていこう。
モノイドを見たときと同じように、**型クラス**、**型クラスのインスタンス**、そして **型クラスの構文** の3つの観点で見ていく。

### ファンクタ型クラス

ファンクタ型クラスは[`cats.Functor`][cats.Functor]にある。
コンパニオンオブジェクトにある標準の`Functor.apply`メソッドを利用して、インスタンスを得ることができる。
いつものように、組み込みのインスタンスは[`cats.instances`][cats.instances]に並べられている:

```tut:book:silent
import scala.language.higherKinds
import cats.Functor
import cats.instances.list._   // for Functor
import cats.instances.option._ // for Functor
```

```tut:book
val list1 = List(1, 2, 3)
val list2 = Functor[List].map(list1)(_ * 2)

val option1 = Option(123)
val option2 = Functor[Option].map(option1)(_.toString)
```

`Functor`は`lift`メソッドも提供している。これは型`A => B`の関数を`F[A] => F[B]`という型を持つ、ファンクタの上で動作する関数に変換する。

```tut:book
val func = (x: Int) => x + 1

val liftedFunc = Functor[Option].lift(func)

liftedFunc(Option(1))
```

### ファンクタの構文

`Functor`の構文によって提供される主要なメソッドは`map`だ。
`Option`や`List`を使ってこれを実演するのは難しい。なぜならこれらの型は組み込みの `map`メソッドを持っており、Scala コンパイラは常に拡張メソッドよりも組み込みのメソッドを優先するためである。
2つの例を用いてこれに対処する。

まず、関数の変換を見ていこう。
Scala の`Function1`型は`map`メソッドを持たない(その代わり、`andThen`と呼ばれている)ので、名前の衝突は発生しない:

```tut:book:silent
import cats.instances.function._ // for Functor
import cats.syntax.functor._     // for map
```

```tut:book:silent
val func1 = (a: Int) => a + 1
val func2 = (a: Int) => a * 2
val func3 = (a: Int) => a + "!"
val func4 = func1.map(func2).map(func3)
```

```tut:book
func4(123)
```

もう1つの例を見ていこう。
特定の具体的な型ではなく、すべてのファンクタに対して動くような抽象化を行う時が来た。
ファンクタが表す文脈にかかわらず、中身の数値に同じ式を適用するようなメソッドを書くことができる:

```tut:book:silent
def doMath[F[_]](start: F[Int])
    (implicit functor: Functor[F]): F[Int] =
  start.map(n => n + 1 * 2)

import cats.instances.option._ // for Functor
import cats.instances.list._   // for Functor
```

```tut:book
doMath(Option(20))
doMath(List(1, 2, 3))
```

これがどのように動作するのか実例を挙げて説明する。`cats.syntax.functor`の`map`メソッドの定義を見てみよう。
これが簡略化されたコードだ:

```scala
implicit class FucntorOps[F[_], A](src: F[A]) {
  def map[B](func: A => B)
      (implicit functor: Fucntor[F]): F[B] =
    functor.map(src)(func)
}
```

コンパイラは、組み込みの`map`メソッドが利用できない場合はいつでも、足りない`map`メソッドを挿入するためにこの拡張メソッドを利用する:

```scala
foo.map(value => value + 1)
```

`foo`が組み込みの`map`メソッドを持たないとする。コンパイラはエラーの可能性を検出し、この式を`FunctorOps`に包んでコードを修正する:

```scala
new FunctorOps(foo).map(value => value + 1)
```

`FunctorOps`の`map`メソッドは暗黙の`Functor`インスタンスを引数として要求している。
これは、`foo`に対する`Functor`のインスタンスがあるときに限りこのコードがコンパイルを通るということを意味する。そうでなければ、コンパイルエラーとなる:

```tut:book:silent
final case class Box[A](value: A)

val box = Box[Int](123)
```

```tut:book:fail
box.map(value => value + 1)
```

### 独自の型に対するインスタンス

ファンクタを定義するには、`map`メソッドを定義するだけでよい。
以下のコードは、`Option`に対する`Functor`の例である。なお、このインスタンスは既に[`cats.instances`][cats.instances]に含まれている。
その実装は自明である---ただ`Option`の`map`メソッドを呼び出しているだけだ:

```tut:book:silent
implicit val optionFunctor: Functor[Option] =
  new Functor[Option] {
    def map[A, B](value: Option[A])(func: A => B): Option[B] =
      value.map(func)
  }
```

時には独自のインスタンスに依存性を持ち込まなければならないこともある。
例えば、`Future`に対する`Fucntor`を定義する必要があるとしよう(これも仮の例だ---Cats には既に`cats.instances.future`を提供している)。
そのためには、`future.map`に渡す暗黙の`ExecutionContext`引数について考慮しなければならない。
インスタンスを作る際に、この依存性を考慮しなければならないため、`future.map`に追加の引数を加えることはできない:


```tut:book:silent
import scala.concurrent.{Future, ExecutionContext}

implicit def futureFunctor
    (implicit ec: ExecutionContext): Functor[Future] =
  new Functor[Future] {
    def map[A, B](value: Future[A])(func: A => B): Future[B] =
      value.map(func)
  }
```

`Future`に対する`Fucntor`を召喚するときはいつも、`Functor.apply`を直接利用するか、間接的に`map`拡張メソッドを経由するかして、暗黙値の解決でコンパイラが`futureFunctor`を見つけ、呼び出し地点における`ExecutionContext`を再帰的に探索する。
この展開は次のように進む:

```scala
// こう書くと:
Functor[Future]

// コンパイラはまずこのように式を展開する:
Fucutor[Future](futureFunctor)

// そしてこうなる:
Functor[Future](futureFunctor(executionContext))
```

### 演習: 分岐するファンクタ

以下の二分木データ型に対する`Functor`を実装せよ。
`Branch`と`Leaf`に対してコードが期待通りに動作することを確認せよ:

```tut:book:silent
object wrapper {
  sealed trait Tree[+A]

  final case class Branch[A](left: Tree[A], right: Tree[A])
    extends Tree[A]

  final case class Leaf[A](value: A) extends Tree[A]
}; import wrapper._
```

<div class="solution">
その意味は、`List`に対する`Functor`と似ている。
データ構造を再帰的に探索し、発見したそれぞれの`Leaf`に対して関数を適用すればいい。
ファンクタの法則は、明らかに`Branch`と`Leaf`について同じ構造を保つことを要求している:

```tut:book:silent
import cats.Functor

implicit val treeFunctor: Functor[Tree] =
  new Functor[Tree] {
    def map[A, B](tree: Tree[A])(func: A => B): Tree[B] =
      tree match {
        case Branch(left, right) =>
          Branch(map(left)(func), map(right)(func))
        case Leaf(value) =>
          Leaf(func(value))
      }
  }
```

`Tree`を変換するために、ここで作った`Functor`を使ってみよう:

```tut:book:fail
Branch(Leaf(10), Leaf(20)).map(_ * 2)
```

おっと![@sec:variance]節で考えたのと同じ、非変による問題に陥ってしまった。
コンパイラは`Tree`に対する`Functor`のインスタンスを見つけることはできるが、`Branch`や`Leaf`に対するインスタンスを見つけることはできない。
埋め合わせるために、スマートコンストラクタを追加しよう:

```tut:book:silent
object Tree {
  def branch[A](left: Tree[A], right: Tree[A]): Tree[A] =
    Branch(left, right)

  def leaf[A](value: A): Tree[A] =
    Leaf(value)
}
```

これで、先程の`Functor`を正しく利用できるようになった:

```tut:book
Tree.leaf(100).map(_ * 2)

Tree.branch(Tree.leaf(10), Tree.leaf(20)).map(_ * 2)
```
</div>
