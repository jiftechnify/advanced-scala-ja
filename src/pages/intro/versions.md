## バージョン {-}

本書では Scala 2.12.3 と Cats 1.0.0 を使用している。
関連する依存関係と設定を含む、最小限の `buils.sbt` は以下のとおりである[^sbt-version]:

```scala
scalaVersion := "2.12.3"

libraryDependencies +=
  "org.typelevel" %% "cats-core" % "1.0.0"

scalacOptions ++= Seq(
  "-Xfatal-warnings",
  "-Ypartial-unification"
)
```

[^sbt-version]: ここでは、SBT 0.13.13 以降の利用を想定している。

### テンプレートプロジェクト {-}

便宜のため、事のはじめに最適な Giter8 テンプレートを用意した。
テンプレートをクローンするには、次のように入力すればいい:

```bash
$ sbt new underscoreio/cats-seed.g8
```

これで、Cats を依存関係に含んだサンドボックスプロジェクトが生成されるはずだ。
サンプルコードを動かす方法や、対話型 Scala コンソールを開始する方法については、自動生成された `README.md` を参照されたい。

`cats-seed` は必要最小限のテンプレートになっている。
もっと多くの「バッテリー」が同梱されたところから始めたければ、Typelevel の `sbt-catalysts` テンプレートを利用するとよい:

```bash
$ sbt new typelevel/sbt-catalysts.g8
```

これは一通りの依存ライブラリやコンパイラプラグインを取り込むと同時に、単体テストと [tutを利用した][link-tut] ドキュメントのためのテンプレートを生成する。
詳しくは、[catalysts][link-catalysts]と[sbt-catalysts][link-sbt-catalysts]のプロジェクトページを参照のこと。
