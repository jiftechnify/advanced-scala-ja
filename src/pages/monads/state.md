## State モナド

[`cats.data.State`][cats.data.State]は、計算の一部として追加の状態を渡してまわることを可能にする。
不可分な状態操作を`State`のインスタンスとして定義し、それらを`map`や`flatMap`を利用して糸を通すように繋いでいく。
これによって、破壊的変更を用いることなく、純粋関数的な方法で可変状態をモデル化することができる。

### State の生成と値の取り出し

最も単純な形まで要約すると、`State[S, A]`のインスタンスは`S => (S, A)`という型の関数を表現している。
`S`は状態の型、`A`は計算の結果の型である。

```tut:book:silent
import cats.data.State
```

```tut:book
val a = State[Int, String] { state =>
  (state, s"The state is $state)
}
```

言い換えれば、`State`のインスタンスは次の2つのことを行う関数である:

- 入力された状態を出力する状態に変換する
- 結果を計算する

このモナドに初期状態を与えることで「実行」することができる。
`State`は、`run`、`runS`、`runA`という3つのメソッドを提供している。これらの違いはどんな状態と結果のうちどれを返すかにある。
それぞれのメソッドは`Eval`のインスタンスを返す。`State`は`Eval`を利用してスタック安全性を維持している。
いつものように、`value`メソッドを呼び出すことで実際の結果を取り出すことができる:

```tut:book
// 状態と結果の両方を得る
val (state, result) = a.run(10).value

// 結果を無視し、状態だけを得る
val state = a.runS(10).value

// 状態を無視し、結果だけを得る
val result = a.runA(10).value
```

### State の合成と変換

`Reader`と`Writer`で見てきたように、`State`モナドの力はそのインスタンスを組み合わせる能力に由来する。
`map`と`flatMap`メソッドはあるインスタンスから別のインスタンスへ状態を受け渡す。
`State`のそれぞれのインスタンスは1つの不可分な状態変換を表現し、その組み合わせは変更の列の全体を表現する:

```tut:book
val step1 = State[Int, String] { num =>
  val ans = num + 1
  (ans, s"Result of step1: $ans")
}

val step2 = State[Int, String] { num =>
  val ans = num * 2
  (ans, s"Result of step2: $ans")
}

val both = for {
  a <- step1
  b <- step2
} yield (a, b)

val (state, result) = both.run(20).value
```

ご覧の通り、この例における最終状態は両方の変換を順番に適用した結果となる。
for 内包表記で直接状態を操作していないのにもかかわらず、状態はステップから別のステップへと通されている。

`State`モナドを利用する一般的なモデルは、`State`のインスタンスとして計算の各ステップを表現し、標準的なモナド演算を利用して複数のステップを合成するというものである。
Cats は、基本のステップを生成するいくつかの便利なコンストラクタを提供している:

 - `get`: 状態を結果として取り出す
 - `set`: 状態を更新し、unitを結果として返す
 - `pure`: 状態を無視して与えられた値を結果として返す
 - `inspect`: 変換関数によって状態を取り出す
 - `modify`: 更新関数を用いて状態を更新する

```tut:book
val getDemo = State.get[Int]
getDemo.run(10).value

val setDemo = State.set[Int](30)
setDemo.run(10).value

val pureDemo = State.pure[Int, String]("Result")
pureDemo.run(10).value

val inspectDemo = State.inspect[Int, String](_ + "!")
inspectDemo.run(10).value

val modifyDemo = State.modify[Int](_ + 1)
modifyDemo.run(10).value
```

これらの構成要素を for 内包表記によって組み立てることができる。
状態の変換だけを表現する中間段階における結果は、無視されることが多い:

```tut:book:silent
import State._
```

```tut:book
val program: State[Int, (Int, Int, Int)] = for {
  a <- get[Int]
  _ <- set[Int](a + 1)
  b <- get[Int]
  _ <- modify[Int](_ + 1)
  c <- inspect[Int, Int](_ * 1000)
} yield (a, b, c)

val (state, result) = program.run(1).value
```

### 演習: 後置記法の計算機

`State`モナドを用いて、可変なレジスタ値を結果と一緒に受け渡すという方法で、複雑な式に対する簡単なインタプリタを実装することができる。
これの単純な例として、後置記法で書かれた整数の算術式の計算機を実装しよう。

後置記法の式という言葉を聞いたことがないかもしれない(聞いたことがなくても、心配は要らない)。それはオペランドのあとに演算子を書く数学的記法である。
例えば、`1 + 2`と書く代わりに、以下のように書く:

```scala
1 2 +
```

後置記法の式は人間には読むのが難しいが、コードによって評価するのは簡単だ。
するべきことは、記号を左から右へ見ていって、オペランドの **スタック** を次のように操作することだけだ:

- 数値ならば、スタックにそれをプッシュする

- 演算子ならば、スタックから2つのオペランドをポップし、演算を行い、結果をスタックにプッシュする

これによって、括弧を使わずに複雑な式を評価できる。
例えば、`(1 + 2) * 3`という式を次のように評価できる:

```scala
1 2 + 3 * // 1 を見つけ、スタックにプッシュ
2 + 3 *   // 2 を見つけ、スタックにプッシュ
+ 3 *     // + を見つけ、1 と 2 をスタックからポップし、
          //             (1 + 2) = 3 をプッシュする
3 3 *     // 3 を見つけ、スタックにプッシュ
3 *       // 3 を見つけ、スタックにプッシュ
*         // * を見つけ、2つの 3 をスタックからポップし、
          //             (3 * 3) = 9 をプッシュする
```

このような式に対するインタプリタを書いてみよう。
それぞれのシンボルを、スタックの変換と中間結果を表現する`State`のインスタンスとして解釈できる。
`State`のインスタンスを`flatMap`を利用して繋ぎ合わせることで、任意のシンボルの列のインタプリタを生成することができる。

まず、1つのシンボルを`State`のインスタンスとしてパースする`evalOne`関数を書いてみよう。
雛形として下のコードを用いよ。
今はエラー処理について心配する必要はない---スタックの状態が異常になった場合は、例外を投げてしまってかまわない。

```tut:book:reset:silent
import cats.data.State

type CalcState[A] = State[List[Int], A]

def evalOne(sym: String): CalcState[Int] = ???
```

難しければ、返すべき`State`インスタンスの基本形について考えてみよう。
それぞれのインスタンスは、あるスタックからスタックと結果の組への関数による変換を表現する。
より広い文脈は無視して、たった1つのステップに集中できる:

```tut:book:invisible
def someTransformation(input: List[Int]): List[Int] = input
def someCalculation: Int = 123
```

```tut:book:silent
State[List[Int], Int] { oldStack =>
  val newStack = someTransformation(oldStack)
  val result   = someCalculation
  (newStack, result)
}
```

この形式で`Stack`のインスタンスを書いてもいいし、上で見たような便利なコンストラクタの連続として書いてもいい。

<div class="solution">
必要とされるスタック操作は、演算子の場合とオペランドの場合で異なる。
分かりやすくするために、`evalOne`をそれぞれの場合に対応する2つのヘルパー関数を用いて実装する:

```scala
def evalOne(sym: String): CalcState[Int] =
  sym match {
    case "+" => operator(_ + _)
    case "-" => operator(_ - _)
    case "*" => operator(_ * _)
    case "/" => operator(_ / _)
    case num => operand(num.toInt)
  }
```

まず`operand`から見ていこう。
することは、スタックに数値をプッシュすることだけだ。
また、オペランドを中間結果として返すようにする:

```tut:book:silent
def operand(num: Int): CalcState[Int] =
  State[List[Int], Int] { stack =>
    (num :: stack, num)
  }
```

`operator`関数は少し複雑だ。
2つのオペランドをスタックからポップし(スタックの先頭を2番めのオペランドとする)、計算結果をスタックにプッシュする。
スタックが十分なオペランドを含まない場合コードは失敗するが、この場合は例外を投げてよい:

```tut:book:silent
def operator(func: (Int, Int) => Int): CalcState[Int] =
  State[List[Int], Int] {
    case b :: a :: tail =>
      val ans = func(a, b)
      (ans :: tail, ans)

    case _ =>
      sys.error("Fail!")
  }
```

```tut:book:invisible
def evalOne(sym: String): CalcState[Int] =
  sym match {
    case "+" => operator(_ + _)
    case "-" => operator(_ - _)
    case "*" => operator(_ * _)
    case "/" => operator(_ / _)
    case num => operand(num.toInt)
  }
```
</div>

`evalOne`によって1つのシンボルからなる式を次のように表現できる。
初期スタックとして`Nil`を与えて`runA`を呼び出し、結果の`Eval`から値を取り出すために`value`を呼び出せばよい:

```tut:book
evalOne("42").runA(Nil).value
```

`evalOne`、`map`、`flatMap`を用いて、より複雑なプログラムを表現できる。
ほとんどの仕事はスタックの上で起きているので、`evalOne("1")`や`evalOne("2")`の中間結果は無視していることに注意してほしい:

```tut:book
val program = for {
  _   <- evalOne("1")
  _   <- evalOne("2")
  ans <- evalOne("+")
} yield ans

program.runA(Nil).value
```

この例を、`List[String]`から結果を計算する`evalAll`を書くことで一般化せよ。
それぞれのシンボルを処理するのに`evalOne`を利用し、結果の`State`モナドを繋ぎ合わせるのに`flatMap`を利用せよ。
関数は次のようなシグネチャを持つことになる:

```tut:book:silent
def evalAll(input: List[String]): CalcState[Int] =
  ???
```

<div class="solution">
入力全体を畳み込むことで`evalAll`を実装する。
入力のリストが空の場合に`0`を返す純粋な`CalcState`から始める。
下の例のように、中間結果を無視しながら、各段階で`flatMap`を行う:

```tut:book:silent
import cats.syntax.applicative._ // for pure

def evalAll(input: List[String]): CalcState[Int] =
  input.foldLeft(0.pure[CalcState]) { (a, b) =>
    a.flatMap(_ => evalOne(b))
  }
```

</div>

`evalAll`を用いて、簡単に複数の段階からなる式を評価できる:

```tut:book
val program = evalAll(List("1", "2", "+", "3", "*"))

program.runA(Nil).value
```

`evalOne`と`evalAll`はどちらも`State`のインスタンスを返すので、`flatMap`を用いてこれらの結果を繋ぐこともできる。
`evalOne`は単純なスタックの変換を生成し、`evalAll`は複雑な変換を生成するが、これらはどちらも純粋な関数であり、どんな順番でも、何回でも好きなように利用できる:

```tut:book
val program = for {
  _   <- evalAll(List("1", "2", "+"))
  _   <- evalAll(List("3", "4", "+"))
  ans <- evalOne("*")
} yield ans

program.runA(Nil).value
```

入力された`String`をシンボルに分割し、`evalAll`を呼び、結果の`State`に初期スタックを与えて実行する`evalInput`関数を実装し、演習を終えよう。

<div class="solution">
難しい仕事はもうやりきってしまった。
ここですることは、入力を項に分割し、`runA`を呼び出し、`value`で結果を取り出すことだけだ:

```tut:book:silent
def evalInput(input: String): Int =
  evalAll(input.split(" ").toList).runA(Nil).value
```

```tut:book
evalInput("1 2 + 3 4 + *")
```
</div>
