# Scala with Cats in Japanese
["Scala with Cats"](https://github.com/underscoreio/advanced-scala)の(非公式)和訳 :cat::jp: (Japanese translation of the book "Scala with Cats")

著: [Noel Welsh](http://twitter.com/noelwelsh) / [Dave Gurnell](http://twitter.com/davegurnell)

訳: Takumi Fujiwara([@jiftechnify](https://github.com/jiftechnify))

挿絵: [Jenny Clements](http://patreon.com/miasandelle)

出版: [Underscore Consulting LLP](http://underscore.io)

<a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/"><img alt="Creative Commons Licence" style="border-width:0" src="https://i.creativecommons.org/l/by-sa/4.0/88x31.png" /></a><br />この著作物は<a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/">Creative Commons Attribution-ShareAlike 4.0 International License</a>のもとで頒布されています。

## 概要

[Scala with Cats][scala-with-cats]は、[Cats](http://typelevel.org/cats)ライブラリと多くの実例を用いて、モノイド・ファンクタ・モナド・アプリカティブファンクタといった、関数プログラミングにおける抽象化手法について解説した書籍である。

## ビルド

Scala with Catsでは、[Underscoreの電子書籍ビルドシステム][ebook-template]を利用している。

この本をビルドする最も簡単な方法は、[Docker Compose](http://docker.com)を使う方法だ:

- Docker Composeをインストール(OS Xなら`brew install docker-compose`。そうでなければ[docker.com](http://docker.com)からダウンロード)し、

- `go.sh`を実行する(`go.sh`が動かなければ、代わりに`docker-compose run book bash`を実行)。

これで、この本をビルドするのに必要なすべての依存ライブラリを含んだDockerコンテナの中で、`bash`シェルが起動した状態になる。
次に、シェルから次のコマンドを順に実行する:

- `npm install`
- `sbt`

`sbt`の中で`pdf`、`html`、`epub`、または`all`コマンドを実行すれば、所望の形式の本がビルドされる。
出力は`dist`ディレクトリに配置される。

## Contributing

TBD

***
(以下、原著のREADME)

# Scala with Cats

Copyright [Noel Welsh](http://twitter.com/noelwelsh)
and [Dave Gurnell](http://twitter.com/davegurnell), 2014-2017.

Artwork by [Jenny Clements](http://patreon.com/miasandelle).

Published by [Underscore Consulting LLP](http://underscore.io).

<a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/"><img alt="Creative Commons Licence" style="border-width:0" src="https://i.creativecommons.org/l/by-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/">Creative Commons Attribution-ShareAlike 4.0 International License</a>.

## Overview

[Scala with Cats][scala-with-cats] teaches
core functional abstractions of monoids, functors, monads, and applicative functors
using the [Cats](http://typelevel.org/cats) library and a number of case studies.

## Building

Scala with Cats uses [Underscore's ebook build system][ebook-template].

The simplest way to build the book is to use [Docker Compose](http://docker.com):

- install Docker Compose (`brew install docker-compose` on OS X;
  or download from [docker.com](http://docker.com/)); and

- run `go.sh` (or `docker-compose run book bash` if `go.sh` doesn't work).

This will open a `bash` shell running inside the Docker container
that contains all the dependencies to build the book.
From the shell run:

- `npm install`; and then
- `sbt`.

Within `sbt` you can issue the commands
`pdf`, `html`, `epub`, or `all`
to build the desired version(s) of the book.
Targets are placed in the `dist` directory.

## Contributing

If you spot a typo or mistake,
please feel free to fork the repo and submit a Pull Request.
Add yourself to `src/pages/contributors.md`
to ensure we credit you for your contribution.

If you don't have time to submit a PR
or you'd like to suggest a larger change
to the content or structure of the book,
please raise an issue instead.

[ebook-template]: https://github.com/underscoreio/underscore-ebook-template
[scala-with-cats]: https://underscore.io/books/scala-with-cats
