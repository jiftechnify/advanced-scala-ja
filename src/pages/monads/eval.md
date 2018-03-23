## Eval モナド {#sec:monads:eval}

[`cats.Eval`][cats.Eval]は様々な **評価のモデル** を抽象化するモナドである。
よく耳にする評価モデルとしては **先行(eager)評価** と **遅延(lazy)評価** の2つがある。
`Eval`はさらに、結果が **メモ化(memoize)** されるかどうかの区別も付け加えている。

### 先行評価、遅延評価、メモ化、オーマイ!

これらの用語は何を意味するのだろうか?

**先行評価** では計算が即時に起こる一方、**遅延評価** では値にアクセスしようとしたときに計算が起こる。
**メモ化** された計算は最初のアクセス時に実行され、その後はキャッシュされた結果を返す。

例えば、Scalaの `val` は先行評価され、メモ化もされる。
目に見える副作用と一緒に計算を実行することでこれを確認することができる。
次の例では、値`x`の計算はアクセス時ではなく、定義した場所で起こっている(先行評価)。
その後再び`x`にアクセスした際は、コードを再実行することなく、記録しておいた値を返す(メモ化あり)。

```tut:book
val x = {
  println("Computing X")
  math.random
}

x // 1回目のアクセス
x // 2回目のアクセス
```

対照的に、`def`による定義は遅延評価され、メモ化されない。
下の例における`y`を計算するコードは、それにアクセスするまで実行されず(遅延評価)、
アクセスするごとに再実行される(メモ化なし):

```tut:book
def y = {
  println("Computing Y")
  math.random
}

y // 1回目のアクセス
y // 2回目のアクセス
```

最後になる(しかし重要だ)が、`lazy val`は遅延評価され、メモ化もされる。
下の例における`z`を計算するコードは、最初にアクセスされるまで実行されない(遅延評価)。
その際の結果はキャッシュされ、それ以降のアクセスではその値が再利用される(メモ化あり):

```tut:book
lazy val z = {
  println("Computing Z")
  math.random
}

z // 1回目のアクセス
z // 2回目のアクセス
```

### Eval の評価モデル

`Eval`は`Now`、`Later`、`Always`という3つのサブ型を持つ。
これらの型の値は、それぞれのクラスのインスタンスを作成し、それを`Eval`型として返す3つのコンストラクタメソッドによって生成する。

```tut:book:silent
import cats.Eval
```

```tut:book
val now = Eval.now(math.random + 1000)
val later = Eval.later(math.random + 2000)
val always = Eval.always(math.random + 3000)
```

`value`メソッドを利用して`Eval`の結果を取り出すことができる:

```tut:book
now.value
later.value
always.value
```

`Eval`のそれぞれの型は、上で定義した評価モデルのうち1つを使って結果を計算する。
`Eval.now`は **即時に** 値を捕捉する。
そのセマンティクスは`val`(先行評価・メモ化あり)と似ている:

```tut:book
val x = Eval.now {
  println("Computing X")
  math.random
}

x.value // 1回目のアクセス
x.value // 2回目のアクセス
```

`Eval.always`は、`def`と同様に、遅延計算を捕捉する:

```tut:book
val y = Eval.always {
  println("Computing Y")
  math.random
}

y.value // 1回目のアクセス
y.value // 2回目のアクセス
```

最後に、`Eval.later`は`lazy val`と同様に、遅延評価でメモ化された計算を捕捉する:

```tut:book
val z = Eval.later {
  println("Computing Z")
  math.random
}

z.value // 1回目のアクセス
z.value // 2回目のアクセス
```

これらの3種類の振る舞いを以下の表にまとめる:

-----------------------------------------------------------------------
Scala              Cats                      特性
------------------ ------------------------- --------------------------
`val`              `Now`                     先行評価、メモ化あり

`lazy val`         `Later`                   遅延評価、メモ化あり

`def`              `Always`                  遅延評価、メモ化なし
------------------ ------------------------- --------------------------

### モナドとしての Eval

他のすべてのモナドのように、`Eval`の`map`と`flatMap`メソッドは計算の連鎖に新たな計算を追加する。
しかし`Eval`の場合、計算の連鎖は関数のリストとして明示的に保持される。
`Eval`の`value`メソッドを呼び出して結果をリクエストするまで、それらの関数は実行されない:

```tut:book
val greeting = Eval.
  always { println("Step 1"); "Hello" }.
  map { str => println("Step 2"); s"$str world" }

greeting.value
```

`Eval`のインスタンスが持つ本来のセマンティクスが保持される一方で、変換関数は常に必要になってはじめて呼び出される(これは`def`のセマンティクスだ):

```tut:book
val ans = for {
  a <- Eval.now { println("Calculating A"); 40 }
  b <- Eval.always { println("Calculating B"); 2}
} yield {
  println("Adding A and B")
  a + b
}

ans.value // 1回目のアクセス
ans.value // 2回目のアクセス
```

`Eval`は、計算の連鎖をメモ化することを可能にする`memoize`メソッドを持つ。
`memoize`が呼び出されるまでの一連の計算の結果がキャッシュされる。一方、そのあとの計算は元のセマンティクスのまま残る:

```tut:book
val saying = Eval.
  always { println("Step 1"); "The cat" }.
  map { str => println("Step 2"); s"$str sat on" }.
  memoize.
  map { str => println("Step 3"); s"$str the mat" }

saying.value // 1回目のアクセス
saying.value // 2回目のアクセス
```

### トランポリン化と *Eval.defer*

`Eval`の有用な性質のひとつとして、`map`と`flatMap`メソッドが **トランポリン化** されていることが挙げられる。
これは、スタックフレームを消費することなく、任意の数の`map`や `flatMap`をネストして呼び出すことができることを意味する。
この性質を **「スタック安全性」** と呼ぶ。

例えば、階乗を計算する以下の関数を考えてみよう:

```tut:book:silent
def factorial(n: BigInt): BigInt =
  if (n == 1) n else n * factorial(n - 1)
```

このメソッドでスタックを溢れさせるのは、比較的簡単なことだ:

```scala
factorial(50000)
// java.lang.StackOverflowError
//   ...
```

`Eval`を使ってこのメソッドを書き換えることで、これをスタック安全にすることができる:

```tut:book:silent
def factorial(n: BigInt): Eval[BigInt] =
  if(n == 1) {
    Eval.now(n)
  } else {
    factorial(n - 1).map(_ * n)
  }
```

```scala
factorial(50000).value
// java.lang.StackOverflowError
//   ...
```

おっと! うまく行かなかった---スタックはやはり吹き飛んでしまった!
これは、いまだに`Eval`の`map`メソッドを利用し始める前に`factorial`の再帰的呼び出しを行っているのが原因である。
`Eval.defer`を利用してこの問題に対処できる。これは既存の`Eval`のインスタンスを受け取って、その評価を先送りする。
`defer`メソッドも`map`や`flatMap`と同様にトランポリン化されているので、これを既存の計算をスタック安全にする手早い方法として利用することができる:

```tut:book:silent
def factorial(n: BigInt): Eval[BigInt] =
  if(n == 1) {
    Eval.now(n)
  } else {
    Eval.defer(factorial(n - 1).map(_ * n))
  }
```

```tut:book
factorial(50000).value
```

`Eval`は非常に大きな計算やデータ構造を処理する際に、スタック安全性を強制するのに役立つ道具である。
しかし、トランポリン化もタダではないということを心に留めておかなければならない。
トランポリン化では、関数オブジェクトの連鎖をヒープ上に生成することで、スタックの消費を回避している。
計算のネストの深さにはやはり限界はあるが、その限界はスタックの大きさではなくヒープの大きさによって決まるのだ。

### 演習: Eval を利用したより安全な畳み込み

下記の単純な`foldRight`の実装はスタック安全ではない。
`Eval`を利用してこれをスタック安全にせよ:

```tut:book:silent
def foldRight[A, B](as: List[A], acc: B)(fn: (A, B) => B): B =
  as match {
    case head :: tail =>
      fn(head, foldRight(tail, acc)(fn))
    case Nil =>
      acc
  }
```

<div class="solution">
これを修正する最も簡単な方法は、`foldRightEval`という名前のヘルパーメソッドを導入することだ。
これは基本的に、各`B`の出現を`Eval[B]`に置き換え、再帰呼び出しを保護するために`Eval.defer`を呼ぶようにしたものである:

```tut:book:silent
def foldRightEval[A, B](as: List[A], acc: Eval[B])
    (fn: (A, Eval[B]) => Eval[B]): Eval[B] =
  as match {
    case head :: tail =>
      Eval.defer(fn(head, foldRightEval(tail, acc)(fn)))
    case Nil =>
      acc
  }
```

`foldRight`を`foldRightEval`を利用して再定義することで、結果として得られるメソッドはスタック安全となる:

```tut:book:silent
def foldRight[A, B](as: List[A], acc: B)(fn: (A, B) => B): B =
  foldRightEval(as, Eval.now(acc)) { (a, b) =>
    b.map(fn(a, _))
  }.value
```

```tut:book
foldRight((1 to 100000).toList, 0L)(_ + _)
```
</div>
