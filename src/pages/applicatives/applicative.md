## Apply と Applicative

Semigroupal は多くの関数プログラミングの文献ではあまり注目されることがない。
Semigroupal は、 **アプリカティブファンクタ(applicative functor)** (略して「アプリカティブ」)と呼ばれる型クラスが持つ機能の一部を提供している。

`Semigroupal`と`Applicative`は実質的に、文脈を結合するという同じ概念の2つの異なるコード化である。
両方のコード化は Conor McBride と Ross Paterson による[同じ2008年の論文][link-applicative-programming]で導入された[^semigroupal-monoidal]。

[^semigroupal-monoidal]: Semigroupal は、この論文では"monoidal"と呼ばれている。

Cats はアプリカティブを2つの型クラスを利用してモデル化している。
1つ目は、`Semigroupal`と`Functor`を継承し、文脈の中の関数を引数に適用する`ap`メソッドを追加した[`cats.Apply`][cats.Apply]である。
2つ目は、`Apply`を継承し、[@sec:monads]章で紹介した`pure`メソッドを追加する[`cats.Applicative`][cats.Applicative]である。
以下に簡素化した定義を示す:

```scala
trait Apply[F[_]] extends Semigroup[F] with Functor[F] {
  def ap[A, B](ff: F[A => B])(fa: F[A]): F[B]

  def product[A, B](fa: F[A], fb: F[B]): F[(A, B)] =
    ap(map(fa)(a => (b: B) => (a, b)))(fb)
}

trait Applicative[F[_]] extends Apply[F] {
  def pure[A](a: A): F[A]
}
```

細かく分析すると、`ap`メソッドは`F[_]`という文脈の中の関数`ff`を引数`fa`に適用する。
`Semigroupal`の`product`メソッドは、`ap`と`map`によって定義されている。

`product`の実装について心配しすぎる必要はない---これを読むのは難しいし、詳細は特別に重要というわけではない。
重要なポイントは、`product`、`ap`、そして`map`の間には強い関係があり、いずれも他の2つのメソッドを利用して定義できるということだ。

`Applicative`はさらに`pure`メソッドを導入する。
これは`Monad`にある`pure`と同じものである。
`pure`は文脈に包まれていない値から新しいアプリカティブのインスタンスを構築する。
この意味で、`Applicative`と`Apply`との間の関係は`Monoid`と`Semigroup`との間の関係に似ている。

### 計算の連鎖を表す型クラスの階層

`Apply`と`Applicative`を紹介したので、様々な方法で計算を連鎖させるような型クラス全体を見渡すことができる。
図[@fig:applicatives:hierarchy]は、本書で説明した型クラス間の関係を示している[^cats-infographic]。

![モナド型クラスの階層](src/pages/applicatives/hierarchy.png){#fig:applicatives:hierarchy}

[^cats-infographic]: 完全な階層図については [Rob Norris のインフォグラフィック][link-cats-infographic]を参照のこと。

階層内のそれぞれの型クラスが、特定の計算の連鎖のセマンティクスを表現している。それぞれが特有のメソッドを導入し、それによってスーパー型の機能を定義している:

- すべてのモナドはアプリカティブでもある
- すべてのアプリカティブは Semigroupal でもある
- 以下同文。

型クラス間の関係は規則に従うため、すべての型クラスのインスタンスにおいて継承関係は一定である。
`Apply`は`ap`と`map`を使って`product`を定義し、
`Monad`は`pure`と`flatMap`を使って`product`、`ap`、そして`map`を定義している。

このことを説明するために、仮説的な2つのデータ型を考えてみよう:

- `Foo`はモナドである。
  これは`pure`と`flatMap`を実装し、`product`、`map`、`ap`の標準的な定義を継承するような`Monad`型クラスのインスタンスを持つ。

- `Bar`はアプリカティブファンクタである。
  これは`pure`と`ap`を実装し、`product`と`map`の標準的な定義を継承するような`Applicative`のインスタンスを持つ。

これ以上の実装の詳細を知らなくても、これらの2つのデータ型について何かいえることはあるだろうか?

`Foo`については`Bar`よりも厳密に多くのことが分かる:
`Monad`は`Applicative`のサブ型なので、`Bar`が保証しないような`Foo`の特性(即ち`flatMap`)を持つことを保証できる。
逆に、`Bar`は`Foo`よりも幅広い振る舞いを持ちうる、ということも分かる。
`Bar`が従うべき法則は(`flatMap`を持たないため)`Foo`よりも少ないので、`Foo`が実装できないような振る舞いを実装できる。

これは、典型的な(数学的な意味での)能力と制限のトレードオフを示す例となっている。
データ型により多くの制限を課すほど、振る舞いについて保証されることも多くなるが、モデル化できる振る舞いの数は減る。

モナドはこのトレードオフの最適解となっている。
モナドは幅広い振る舞いをモデル化するのに十分な柔軟性を持つ一方、その振る舞いに関する強力な保証を課すのに十分限定的である。
しかし、モナドが仕事をこなすための適切な道具ではない状況も存在する。
時には、ブリトーでは満足できず、タイ料理を食べたくなることもあるだろう。

モナドが、モデル化する計算に厳格な **逐次的** 振る舞いを強いるのに対し、
アプリカティブや Semigroupal がそのような制限を課すことはない。
これは、この階層における別の最適解である。
これらを用いて、モナドが表現できない並行・独立な計算を表現することができる。

データ構造の選択はセマンティクスの選択である。
モナドを選べば、厳密な逐次的セマンティクスを強いられる。
アプリカティブを選べば、`flatMap`を行う能力は得られない。
これは一貫性のある法則によって強いられるトレードオフである。
型はよく考えて選ぼう!
