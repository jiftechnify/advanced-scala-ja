## 反変ファンクタと非変ファンクタ {#contravariant-invariant}

これまで見てきたように、`Functor`の`map`メソッドは連鎖する計算列の最後に新しい計算を「追加」すると考えることができる。
ここからは見ていく2つの型クラスのうち、ひとつは計算列の **最初** に新しい計算を追加する。もうひとつは、**両方向** の計算の列を構成する。これらはそれぞれ、 **反変ファンクタ**・**非変ファンクタ** と呼ばれているものである。

<div class="callout callout-info">
**この節を読むかはあなた次第だ!**

次章で見ていく、モナドという本書で最も重要なパターンを理解するのに、反変・非変ファンクタの知識は必要ない。
しかし、反変・非変ファンクタの知識は、[@sec:applicatives]章で見る`Semigroupal`や`Applicative`について議論する際は役に立つ。

モナドについて知りたくてたまらないならば、[@sec:monads]章まで飛ばしてかまわない。
[@sec:applicatives]章を読む前に、ここに戻ってくればいい。
</div>

### 反変ファンクタと *contramap* メソッド {#contravariant}

1つ目の型クラスである **反変ファンクタ** は`contramap`と呼ばれる演算を提供している。これは「計算の列の前に新しい計算を追加する」ことを表現する。
一般的な型シグネチャは図[@fig:functors:contramap-type-chart]に示した通りである。

![型チャート: contramap メソッド](src/pages/functors/generic-contramap.pdf+svg){#fig:functors:contramap-type-chart}

`contramap`メソッドは、**データの変換** を表現するデータ型に対してのみ意味を成す。
例えば、`Option[B]`型の値を`A => B`型の関数に対し「逆方向に」与える方法は存在しないので、`Option`に対して`contramap`を定義することはできない。
一方、[@sec:type-classes]章で考えた`Printable`型クラスに対しては`contramap`を定義できる:

```tut:book:silent
trait Printable[A] {
  def format(value: A): String
}
```

`Printable[A]`は型`A`から`String`への変換を表している。
その`contramap`メソッドは`B => A`型の関数`func`を受け取り、新しい`Printable[B]`を生成する:

```tut:book:silent
trait Printable[A] {
  def format(value: A): String

  def contramap[B](func: B => A): Printable[B] =
    ???
}

def format[A](value: A)(implicit p: Printable[A]): String =
  p.format(value)
```

#### 演習: contramapで見せびらかそう

上記の`Printable`に対する`contramap`メソッドを実装せよ。
次のコードテンプレートから始めて、`???`を動作するメソッドの本体で置き換えよう:

```tut:book:silent
trait Printable[A] {
  def format(value: A): String

  def contramap[B](func: B => A): Printable[B] =
    new Printable[B] {
      def format(value: B): String =
        ???
    }
}
```

行き詰まったら、型を考えてみよう。
今しなければならないことは、型`B`の値`value`を`String`に変えることだ。
今使える関数とメソッドは何だろうか? それらをどの順で組み合わせればよいだろうか?

<div class=="solution">
以下に動作する実装を示す。
まず`func`によって型`B`の値を型`A`に変換し、それから元々の`Printable`を使って`A`の値を`String`に変換している。
外側と内側の`Printable`を区別するために、外側の方に`self`という別名をつけるトリックを利用している:

```tut:book:silent
trait Printable[A] {
  self =>

  def format(value: A): String

  def contramap[B](func: B => A): Printable[B] =
    new Printable[B] {
      def format(value: B): String =
        self.format(func(value))
    }
}

def format[A](value: A)(implicit p: Printable[A]): String =
  p.format(value)
```
</div>

テスト用に、`String`と`Boolean`に対する`Printable`のインスタンスを定義しよう:

```tut:book:silent
implicit val stringPrintable: Printable[String] =
  new Printable[String] {
    def format(value: String): String =
      "\"" + value + "\""
  }

implicit val booleanPrintable: Printable[Boolean] =
  new Printable[Boolean] {
    def format(value: Boolean): String =
      if(value) "yes" else "no"
  }
```

```tut:book
format("hello")
format(true)
```

さて、次のような`Box`ケースクラスに対する`Printable`を定義しよう。
[@sec:type-classes:recursive-implicits]節で説明したように、この場合は`implicit def`と書く必要がある:

```tut:book:silent
final case class Box[A](value: A)
```

また、`new Printable[Box]...`のようにゼロからすべての定義を書くのではなく、`contramap`を利用して既存のインスタンスから新しいインスタンスを作り出してみよ。

<div class="solution">
任意の型を含む`Box`に対し、ジェネリックなインスタンスを作るには、`Box`の中身の型に対する`Printable`をベースにする。
すべての定義を自分の手で書くこともできる:

```tut:book:silent
implicit def boxPrintable[A](implicit p: Printable[A]) =
  new Printable[Box[A]] {
    def format(box: Box[A]): String =
      p.format(box.value)
  }
```

また、暗黙のパラメータの`contramap`を利用することもできる:

```tut:book:silent
implicit def boxPrintable[A](implicit p: Printable[A]) =
  p.contramap[Box[A]](_.value)
```

`contramap`を利用する方法はよりシンプルであり、純粋な関数コンビネータを利用してシンプルな構成要素を組み合わせることで問題を解決するという、関数プログラミング的なアプローチを示す例となっている。
</div>

あなたのインスタンスは次のように動作するだろう:

```tut:book
format(Box("hello world"))
format(Box(true))
```

`Box`の中身の型に対する`Printable`のインスタンスがなければ、`format`の呼び出しはコンパイルに失敗する:

```tut:book:fail
format(Box(123))
```

### 非変ファンクタと *imap* メソッド {#sec:functors:invariant}

**非変ファンクタ** は`imap`メソッドを実装する。これは簡単にいえば`map`と`contramap`を組み合わせたものに等しい。
`map`は関数を計算列の最後に追加することで新しい型クラスのインスタンスを作り、`contramap`は関数を計算列の一番前に追加することで新しい型クラスのインスタンスを作る。そして`imap`は、両方向の変換の組によって新しい型クラスインスタンスを作る。

非変ファンクタの最も分かりやすい例は、Play JSONの[`Format`][link-play-json-format]や scodec の[`Codec`][link-scodec-codec]のような、エンコードとデコードを1つのデータ型として表現するような型クラスである。
`Printable`を拡張し、`String`へのエンコード・`String`からのデコードを両方サポートする`Codec`を作ることができる:

```tut:book:silent
trait Codec[A] {
  def encode(value: A): String
  def decode(value: String): A
  def imap[B](dec: A => B, enc: B => A): Codec[B] = ???
}
```

```tut:book:invisible
trait Codec[A] {
  self =>

  def encode(value: A): String
  def decode(value: String): A

  def imap[B](dec: A => B, enc: B => A): Codec[B] =
    new Codec[B] {
      def encode(value: B): String =
        self.encode(enc(value))

      def decode(value: String): B =
        dec(self.decode(value))
    }
}
```

```tut:book:silent
def encode[A](value: A)(implicit c: Codec[A]): String =
  c.encode(value)

def decode[A](value: String)(implicit c: Codec[A]): A =
  c.decode(value)
```

`imap`の型チャートは図[@fig:functors:imap-type-chart]に示したとおりである。
`Codec[A]`と関数の組 `A => B`と`B => A`があれば、`imap`メソッドによって`Codec[B]`を作り出すことができる:

![型チャート: imap メソッド](src/pages/functors/generic-imap.pdf+svg){#fig:functors:imap-type-chart}

利用例を挙げる。`encode`メソッドも`decode`メソッドも何もしない、基本の`Codec[String]`があるとしよう:

```tut:book:silent
implicit val stringCodec: Codec[String] =
  new Codec[String] {
    def encode(value: String): String = value
    def decode(value: String): String = value
  }
```

`imap`を利用することで、`stringCodec`を基にして他の型の値を変換するのに使えるたくさんの便利な`Codec`を構成できる:

```tut:book:silent
implicit val intCodec: Codec[Int] =
  stringCodec.imap(_.toInt, _.toString)

implicit val booleanCodec: Codec[Boolean] =
  stringCodec.imap(_.toBoolean, _.toString)
```

<div class="callout callout-info">
**失敗に対処する**

ここで作った`Codec`型クラスの`decode`メソッドは、変換に失敗することを考慮に入れていないことに注意してほしい。
より洗練された関係をモデリングしたければ、ファンクタの先にある概念である、`lens`や`optics`を見てみよう。

Optics は本書の扱う範囲を超えているが、Julien Truffaut による[Monocle][link-monocle]ライブラリがさらなる探求の良い起点となるだろう。
</div>

#### 演習: *imap* がもたらす革新的思考法

先程の`Codec`に対する`imap`メソッドを実装せよ。

<div class="solution">
動作する実装を以下に示す:

```tut:book:silent:reset
trait Codec[A] {
  def encode(value: A): String
  def decode(value: String): A

  def imap[B](dec: A => B, enc: B => A): Codec[B] = {
    val self = this
    new Codec[B] {
      def encode(value: B): String =
        self.encode(enc(value))

      def decode(value: String): B =
        dec(self.decode(value))
    }
  }
}
```

```tut:book:invisible
implicit val stringCodec: Codec[String] =
  new Codec[String] {
    def encode(value: String): String = value
    def decode(value: String): String = value
  }

implicit val intCodec: Codec[Int] =
  stringCodec.imap[Int](_.toInt, _.toString)

implicit val booleanCodec: Codec[Boolean] =
  stringCodec.imap[Boolean](_.toBoolean, _.toString)

def encode[A](value: A)(implicit c: Codec[A]): String =
  c.encode(value)

def decode[A](value: String)(implicit c: Codec[A]): A =
  c.decode(value)
```
</div>

`Double`に対する`Codec`を作り、あなたの`imap`メソッドが動作することを実証せよ。

<div class="solution">
`stringCodec`の`imap`メソッドを利用してこれを実装することができる:

```tut:book:silent
implicit val doubleCodec: Codec[Double] =
  stringCodec.imap[Double](_.toDouble, _.toString)
```
</div>

最後に、以下の`Box`型に対する`Codec`を実装せよ:

```tut:book:silent
case class Box[A](value: A)
```

<div class="solution">
任意の型`A`の値を含む`Box[A]`に対するジェネリックな`Codec`が必要だ。
暗黙のパラメータを用いてスコープに入れた`Codec[A]`の`imap`を呼び出すことで、これを作ることができる:

```tut:book:silent
implicit def boxCodec[A](implicit c: Codec[A]): Codec[Box[A]] =
  c.imap[Box[A]](Box(_), _.value)
```
</div>

あなたの作ったインスタンスは次のように動作するはずだ:

```tut:book
encode(123.4)
decode[Double]("123.4")

encode(Box(123.4))
decode[Box[Double]]("123.4")
```

<div class="callout callout-warning">
**どうしてこんな名前なの?**
「反変」、「非変」、そして「共変」という言葉と、ファンクタの種類との間には、どんな関係があるのだろうか?

[@sec:variance]節を思い出すと、変性(variance)はサブタイピングに影響するものだ。本質的には、サブタイピングとは、コードを破壊することなくある型の値を他の型の値が要求されている場所で利用する能力である。

サブタイピングはある種の変換とみなすことができる。
`B`が`A`のサブ型ならば、常に`B`型の値を`A`型に変換できる。

同様に、`A => B`という関数が存在するとき、`A`は`B`のサブ型であるということができる。
これが、まさに通常の共変ファンクタが捉えているものである。
`F`が共変ファンクタならば、`F[A]`の値と`A => B`という変換があればいつでも、`F[A]`の値を`F[B]`に変換できる。

反変ファンクタはこれと逆方向の変換を捉えている。
`F`が反変ファンクタならば、`F[A]`の値と`B => A`という変換があればいつでも、`F[A]`の値を`F[B]`に変換できる。

非変ファンクタは、`A => B`型の関数によって`F[A]`を`F[B]`に変換でき、かつ`B => A`型の関数によって`F[B]`を`F[A]`に変換できるという場合を捉えたものである。
</div>
