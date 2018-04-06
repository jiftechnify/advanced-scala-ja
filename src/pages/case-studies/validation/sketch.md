## ライブラリの構造のスケッチ

まずは、基盤となる、データの各部分をチェックするところから始めよう。
コードを書き始める前に、何を作ればいいかということについて考えてみよう。
グラフィカルな記述が助けになるだろう。
先程掲げた目標の一つ一つについて詳しく見ていく。

**エラーメッセージの提供**

最初の目標は、チェックの失敗に、有用なエラーメッセージを対応付けることだ。
チェックの出力は、チェックを通過した場合はチェックされた値、そうでなければ何らかのエラーメッセージとなるだろう。
これを、文脈の中の値として抽象的に表現できる。ここで、「文脈」とは、図[@fig:validation:result]に示すような「エラーメッセージである可能性」である。

![妥当性検査の結果](src/pages/case-studies/validation/result.pdf+svg){#fig:validation:result}

したがって、図[@fig:validation:check]に示すように、チェックそれ自体はある値を「文脈に入った値」に変換するような関数となる。

![妥当性検査](src/pages/case-studies/validation/check.pdf+svg){#fig:validation:check}

**チェックの合成**

小さなチェックを組み合わせて大きなチェックを構成するにはどうすればよいだろうか?
これは、図[@fig:validation:applicative]のような、アプリカティブや semigroupal となるのだろうか?

![アプリカティブによるチェックの合成](src/pages/case-studies/validation/applicative.pdf+svg){#fig:validation:applicative}

そうではない。
アプリカティブによる合成では、両方のチェックが同じ値に適用され、結果は同じ値を繰り返したタプルとなる。
必要なのは、どちらかといえば図[@fig:validation:monoid]のようなモノイドである。
意味のある単位元(常に成功裡に終わるチェック)と、合成を行う2つの二項演算(*and* と *or*) を定義できる:

![モノイドによるチェックの合成](src/pages/case-studies/validation/monoid.pdf+svg){#fig:validation:monoid}

ライブラリを利用する際、*and* と  *or* を同じくらいの頻度で用いることになるだろう。ルールを合成する際に何度も2つのモノイドを行き来しなければならないのは面倒だ。
そこで、実際にモノイドの API を用いるのではなく、代わりに`and`と`or`の2つのメソッドを利用することにしよう。

**チェック中のエラーの収集**

モノイドはエラーメッセージを集めるのに適した機構だと考えられる。
メッセージを`List`や`NonEmptyList`として保持すれば、Cats にある既存のモノイドを利用することもできる。

**チェック中のデータ変換**

データのチェックに加え、それを変換するという目標もある。
これは`map`や `flatMap`のようなものになると考えられる(どちらになるかは、変換が失敗するか否かによる)。
よって、図[@fig:validation:monad]に示すように、チェックはモナドでもあると考えられる。

![モナドによるチェックの合成](src/pages/case-studies/validation/monad.pdf+svg){#fig:validation:monad}

ライブラリを馴染みの深い抽象にまで分解できた。そろそろ開発を始めるのにいい頃合いだ。