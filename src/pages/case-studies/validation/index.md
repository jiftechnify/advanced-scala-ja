# 事例: データの妥当性検査

この事例では妥当性検査(validation)のためのライブラリを構築する。
妥当性検査とは何を意味するのだろうか?
多くのプログラムは、その入力が一定の基準に適合しているかどうかチェックする必要がある。
ユーザー名は空白であってはならない、Eメールアドレスは正しい形式でなければならない、などのように。
この類の妥当性検査は Web フォームでよく見られるものだが、設定ファイルや Web サービスのレスポンスのような、正しさを保証できないデータを扱うすべての場合に行われるものである。
例えば、認証(Authentication)は、単なる妥当性検査の特殊な形式である。

これらの確認を行うライブラリを構築したい。
設計の目標はどのようにすべきだろうか?
発想の助けとして、行いたいチェックの種類の例を見ていこう:

- ユーザは18歳以上であるか、そうでなければ保護者の同意が必要である

- `String`型として入力された ID は`Int`として解析でき、
  さらに結果の`Int`値は妥当なレコードの ID に対応していなければならない

- オークションで品物に付ける値段は必ず1つ以上の品物に適用され、正の数でなければならない

- ユーザ名は少なくとも4文字で、すべての文字は英数字でなければならない

- Eメールアドレスはただひとつの`@`記号を含まなければならない。
  `@`で分割したとき、その左側は空でなく、右側は少なくとも3文字の長さで、ドットを含まなければならない

これらの例を踏まえ、いくつかの目標を定める:

- ユーザに「なぜそのデータが妥当でないのか」を知らせるために、検査の失敗それぞれに有意義なメッセージを対応付けることができるようにする。

- 小さなチェックを組み合わせることで、大きなチェックを構築できるようにする。
  例えば、ユーザ名のチェックを、文字列長のチェックと英数字かどうかのチェックを組み合わせることで得られるようにする。

- チェック中にデータを変換できるようにする。
  上の例の中には、データを解析し、その型を`String`から`int`に変換するものが含まれている。

- 最後に、ユーザが再送信の前にすべての問題を解決できるようにするために、すべての失敗を1回の実行で集める。

これらの目標は、データの一部分をチェックするという仮定に基づくものである。
データの複数の部分におけるチェックを組み合わせる必要もある。
例えばログインフォームでは、ユーザ名とパスワードのチェック結果を組み合わせる必要がある。
しかし、この機能は結局ライブラリの小さな構成要素に過ぎないということが後にわかる。そこで、ほとんどの時間を、1つのデータ要素のチェックに費やすことにする。
