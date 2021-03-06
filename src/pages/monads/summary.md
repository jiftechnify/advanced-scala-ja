## まとめ

本章ではモナドを詳しく見てきた。
`flatMap`は、どの計算がどの順番で行われるべきかを指図しながら、計算を連鎖させるような演算だとみなすことができる。
この観点からいえば、`Option`はエラーメッセージなしで失敗しうる計算を、`Either`はメッセージとともに失敗しうる計算を、`List`は複数の結果がある可能性を、そして`Future`は将来のある時点で値を生成しうる計算を、それぞれ表現しているといえる。

`Id`、`Reader`、`Writer`、そして`State`を含む、Cats が提供する独自の型やデータ構造についても見てきた。
これらは多くの用途に用いることができる。

最後に、万一独自のモナドを実装しなければならなくなったときのために、`tailRecM`を利用して独自のモナドインスタンスを定義する方法についても学んだ。
`tailRecM`は、デフォルトでスタック安全な関数プログラミングライブラリを構成することを可能にするための「しわ寄せ」である。
モナドを理解するのに `tailRecM`を理解する必要はない。しかし、これがあることは、モナドを含むコードを書く際に有り難みをもたらすだろう。
