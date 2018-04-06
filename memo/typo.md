# 誤字

## intro
### conventions
> l43.
> We use three types of *callout box* to highlight particular content:

- 3種類と書いてあるが、実際には2種類しか導入されていない。

## case-studies
### map-reduce
#### index
> l461.
> `Foldable` and `Traverseable` type classes.

- `Traverseable`は`Traverse`の間違いか?

> l516.
> The call to `map` then combines the `match` using

- `match`とは? batchの間違いと解釈して訳しておく

### validation
#### kleisli
> l11.
We can abstract `A => Validated[E, A]` to `A => F[B]`,

- 左辺は`A => Validated[E, B]`の間違いだと思われる

### crdt
#### generalisation
> l83.
> Since `increment` and `get` both use

- `get`とは? 文脈的にはおそらく`total`

> l108.
> but doesn't provide one
> for bounded semilattice[^spire].

- `BoundedSemiLattice`型クラスは存在するように見える
  + [ソース](https://github.com/typelevel/cats/blob/master/kernel/src/main/scala/cats/kernel/BoundedSemilattice.scala)
  + ないので自分で作る流れになっている。あることにすれば自作部分はカットすることになる。

#### abstraction
> l89.
> to place it in glocal implicit scope:

- glocalはglobalのミスと思われる
  + glocalという単語は存在するが、文脈的にもglobalが正しそう
