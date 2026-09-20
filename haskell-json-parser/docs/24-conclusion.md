# 24. 振り返りと発展課題

お疲れ様でした。ゼロから、エラー位置つきの JSON パーサを2バージョン
(バックトラッキング版と、Zipper + 先読み版)実装しました。

## 全体を振り返る

- **Functor**(`fmap`/`<$>`): 文脈の中身だけを変換する。
- **Applicative**(`pure`/`<*>`): 複数の独立した処理を組み合わせる。
- **Alternative**(`empty`/`<|>`、`some`/`many`/`optional`):
  失敗したら別の手段を試す(バックトラッキング)。
- **Monad**(`>>=`、`do` 構文): 前の処理の結果を見てから、次に何をするか
  動的に決める。

この4つの型クラスを、パーサという具体的な題材を通して、必要になった
タイミングで1つずつ導入し、自分の手で instance を実装しました。
これらは Haskell のあらゆるライブラリで再利用される共通の語彙です。
今後 `Either`, `IO`, 各種パーサライブラリ(Megaparsec, Attoparsec など)、
`Gen`(QuickCheck)のドキュメントを読むときも、「これは
`Functor`/`Applicative`/`Monad`/`Alternative` のどれの話をしているのか」
という軸で整理できるようになっているはずです。

- **バックトラッキング vs 先読み**: `<|>` によるバックトラッキングは
  「両方試して、後で失敗の理由を選ぶ」ため、エラー報告と相性が悪いことを
  実際に手を動かして確認しました(14)。先読み(`lookahead`)を使えば、
  1文字も消費せずに「次にどのパーサを試すべきか」を確定でき、
  誤ったエラーメッセージを避けられます。
- **Zipper**: カーソル位置を持つデータ構造という考え方を、
  `ListZipper`(15)から `TextZipper`(16)へと発展させ、
  「何行目・何列目にいるか」を追跡する土台にしました。

## 発展課題

余力があれば、以下にも挑戦してみてください。

1. **Negative Testing**: このプロジェクトの QuickCheck プロパティは
   すべて「妥当な JSON を生成してパースが成功するか」という
   **Positive Test** です。「意図的に壊れた JSON を生成して、
   パースが正しく失敗するか」を検証する **Negative Test** は
   用意されていません(元のブログ記事の著者も、これを読者への課題として
   残しています)。例えば「ランダムな `JValue` を `stringify` した後、
   ランダムな1文字を削除・変更・挿入する」ジェネレータを書き、
   「パースが失敗するか、あるいは(たまたま)別の妥当な JSON として
   パースされるかのどちらかである」ことを検証するプロパティを
   書いてみてください。
2. **エラーメッセージの文脈をさらに改善する**: 現在のエラーメッセージは
   「英語」です。`errorMsgForChar`/`elseThrow` に渡すメッセージ文字列を
   日本語に差し替えたり、`jObject` のキーが重複していたらエラーにする
   (現状は許容している)などの改善を試してみてください。
3. **Predictive Parser の完成形を読む**: `solutions/Solutions/Part1.hs`
   に含まれる `jValueAlt`/`jBoolAlt` は、Part1(バックトラッキング版)の
   `Parser` のまま先読みを試した中間形態です。Part2 で最終的に
   たどり着いた設計と見比べて、何が同じで何が違うか整理してみてください。
4. **本物のライブラリを覗いてみる**: [Megaparsec](https://hackage.haskell.org/package/megaparsec)
   や [Attoparsec](https://hackage.haskell.org/package/attoparsec) の
   ソースコードを眺めてみてください。中身は今回よりずっと複雑ですが、
   骨格(`Functor`/`Applicative`/`Monad`/`Alternative` のインスタンスが
   中心にある)は同じです。この教材で得た土台があれば、以前よりずっと
   読み解きやすくなっているはずです。

## 参考資料

- [JSON Parsing from Scratch in Haskell](https://abhinavsarkar.net/posts/json-parsing-from-scratch-in-haskell/)
- [JSON Parsing from Scratch in Haskell: Error Reporting—Part 1](https://abhinavsarkar.net/posts/json-parsing-from-scratch-in-haskell-2/)
- [JSON Parsing from Scratch in Haskell: Error Reporting—Part 2](https://abhinavsarkar.net/posts/json-parsing-from-scratch-in-haskell-3/)
- [RFC 8259 (JSON)](https://www.rfc-editor.org/rfc/rfc8259)
- ["Parsing JSON is a Minefield"](https://seriot.ch/projects/parsing_json.html)
  (Part1 の脚注で触れられている、JSON パーサの正しさを検証するための
  テストスイートを作った記事)
