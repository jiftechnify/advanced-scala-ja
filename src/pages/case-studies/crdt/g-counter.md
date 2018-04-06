## GCounter

ひとつの CRDT 実装を見ていくことにしよう。
それから、その中に普遍的なパターンを見つけるために、その性質の一般化を試みる。

ここで見ていくデータ構造は *GCounter* と呼ばれるものだ。
これは分散化された **インクリメントのみ可能** なカウンタで、例えば多数の web サーバがリクエストを受け入れるような web サイトで訪問者数を数えるのに利用できる。

### 単純なカウンタ

直接的なカウンタが正しく動作しない理由を見るために、2つのサーバが訪問者数の単純な数を保持しているところを想像してみよう。
これらのマシンを`A`、`B`と呼ぶことにしよう。
図[@fig:crdt:simple-counter1]に示すように、それぞれのマシンは整数のカウンタを保持し、すべてのカウンタはゼロから始まるものとする。

![単純なカウンタ: 初期状態](src/pages/case-studies/crdt/simple-counter1.pdf+svg){#fig:crdt:simple-counter1}

さて、いくらかの web トラフィックを受けたところを想像しよう。
ロードバランサが受け取った5つのリクエストを`A`と`B`に分配し、`A`が3人の、`B`が2人の訪問者を担当したとする。
2つのマシンはシステムの状態について一貫しない見方をしており、整合性を達成するためにこれを **調停(reconcile)** する必要がある。
単純なカウンタの調停戦略のひとつは、図[@fig:crdt:simple-counter3]のように、カウントを交換してそれらを足し合わせるというものだ。

![単純なカウンタ: 1度目のリクエストと調停](src/pages/case-studies/crdt/simple-counter3.pdf+svg){#fig:crdt:simple-counter3}

今のところ問題ないが、すぐに事態は悪化し始める。
`A`が1人の訪問者を受け入れたとする。つまり、これまでに合計で6人の訪問者を見たことになる。
マシンたちは、加算によって再び状態を調停しようと試み、図[@fig:crdt:simple-counter5]に示すような結果をもたらす。

![単純なカウンタ: 2度目のリクエストと(間違った)調停](src/pages/case-studies/crdt/simple-counter5.pdf+svg){#fig:crdt:simple-counter5}

これは明らかに間違いだ!
問題は、単純なカウンタがマシン間の相互作用の履歴に関する十分な情報をもたらさないということだ。
幸い、正しい答えを得るのに **完全な** 履歴を保持する必要はない---その概要がありさえすればよい。
GCounter がこの問題をいかにして解決するのかを見ていこう。

### GCounter

GCounter の最初の賢いアイディアは、それぞれのマシンが、各マシン(自身も含む)ごとの知識を保持する別々のカウンタを持つようにする、というものだ。
前の例には`A`と`B`の2つのマシンが登場した。
この場合、図[@fig:crdt:g-counter1]のように、両方のマシンが`A`に対するカウンタと`B`に対するカウンタを持つ。

![GCounter: 初期状態](src/pages/case-studies/crdt/g-counter1.pdf+svg){#fig:crdt:g-counter1}

GConterのルールは、それぞれのマシンは自分自身のカウンタだけをインクリメントできるというものだ。
`A`が3人の訪問者を、`B`が2人の訪問者を受け入れたとすると、カウンタは図[@fig:crdt:g-counter2]のようになる。

![GCounter: 1度目の web リクエスト](src/pages/case-studies/crdt/g-counter2.pdf+svg){#fig:crdt:g-counter2}

2つのマシンがカウンタを調停する際のルールは、各マシンに対するカウンタの最も大きい値をとる、というものだ。
この例では、1度目のマージの結果は図[@fig:crdt:g-counter3]のようになる。

![GCounter: 1度目の調停](src/pages/case-studies/crdt/g-counter3.pdf+svg){#fig:crdt:g-counter3}

この後の web リクエストは「自分自身のカウンタをインクリメントする」ルールに基づき処理され、調停は「最大値をとる」ルールに基づき処理される。その結果、図[@fig:crdt:g-counter5]のように、各マシンについて同じ正しい値が出力される。

![GCounter: 2度目の調停](src/pages/case-studies/crdt/g-counter5.pdf+svg){#fig:crdt:g-counter5}

GCounterによって、完全な相互作用の履歴を保持することなく、各マシンがシステム全体の正確な状態を把握できるようになる。
web サイト全体の合計トラフィックを計算したければ、各マシンはマシンごとのカウンタの合計を計算すればよい。
結果は、調停をどれだけ最近に行ったかによるが、正確または正確に近いものとなる。
結果的には、ネットワークの停止にかかわらず、システムは常に整合的な状態に収束する。

### 演習: GCounter の実装

次のようなインターフェイスに従って、GCounterを実装できる。マシンの ID は`String`の形で表現される。

```tut:book:silent
final case class GCounter(counters: Map[String, Int]) {
  def increment(machine: String, amount: Int) =
    ???

  def merge(that: GCounter): GCounter =
    ???

  def total: Int =
    ???
}
```

実装を完成させよう!

<div class="solution">
上記の説明が、次のような実装にたどり着くのに十分明確であったならば幸いである。

```tut:book:silent
final case class GCounter(counters: Map[String, Int]) {
  def increment(machine: String, amount: Int) = {
    val value = amount + counters.getOrElse(machine, 0)
    GCounter(counters + (machine -> value))
  }

  def merge(that: GCounter): GCounter =
    GCounter(that.counters ++ this.counters.map {
      case (k, v) =>
        k -> (v max that.counters.getOrElse(k, 0))
    })

  def total: Int =
    counters.values.sum
}
```
</div>
