# Foldable と Traverse {#sec:foldable-traverse}

本章では、コレクションの反復処理を捉えた2つの型クラスを見ていく:

  - `Foldable`は、おなじみの`foldLeft`と`foldRight`を抽象化する
  - `Traverse`は、`Applicative`を反復処理に利用する、畳み込みよりも痛みが少なくより高レベルな抽象化である。

まず`Foldable`から見ていく。次に、畳み込みが複雑になり、`Traverse`が便利になるような事例を詳しく調べていく。
