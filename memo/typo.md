# 誤字

## intro
### conventions
> l43.
> We use three types of *callout box* to highlight particular content:

- 3種類と書いてあるが、実際には2種類しか導入されていない。

## monoids
### index
> l160.
> definition of Cats' [`Monoid`][cats.Monoid] is:

- Semigroupの説明なのにMonoidになってる

## functors
### cats
> l123.
> if we have a `Functor` for `expr1` in scope.

- `expr1`は`foo`の間違いと思われる。

> l138.
> We can define a functor simply by defining its map method.

- `map`がバッククオートで囲まれていないのはおそらくミス

## monads
### index
> l14.
> This type class is one of the benefits bought to us by Cats.

- "bought"は"brought"のtypoでは?


### monad-error
> l155.

- 演習を作ろうとした形跡があるが、問題文がない

### writer
> l280.

- `Semigroup`で十分だし本文でも`Semigroup`となっているが、コメントが`for Monoid`

### state
> l159.
> For example, we can evaluate `(1 + 2) * 3)` as follows:

- 最後の括弧が余計

## applicatives
### index
> l52.
> The calls to `parseInt` and `Future.apply` above

- 上に`Future.apply`の呼び出しは登場していない。コード例が間違っている?

### validated
> l250.

- なぜかコメントアウトされている

## foldable-traverse
### traverse
> l80.

- foldLeftの第1引数の型が違う
  + Future(List.empty[A]) -> Future(List.empty[B])
