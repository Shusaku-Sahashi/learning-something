# 12. なぜエラーハンドリングが必要か

対応する実装ファイル: `src/Exercise/Part2/Parser.hs`(ここから Part2 です)

## Part1 の弱点をもう一度

Part1 の `parseJSON` は、失敗すると `Nothing` を返すだけでした。

```
ghci> parseJSON "{\"a\": 1"
Nothing
```

実用的なパーサ ―― たとえば Haskell の著名なパーサライブラリ
[Megaparsec](https://hackage.haskell.org/package/megaparsec) ―― は、
こんなふうにエラーを報告します(イメージ)。

```
1:4:
  |
1 | aaacc
  |    ^
unexpected 'c'
expecting 'a' or 'b'
in foo, in bar
```

何が(`unexpected 'c'`)、何を期待していたときに(`expecting 'a' or 'b'`)、
どこで(`1:4`、1行4列目)、どんな文脈で(`in foo, in bar`)起きたかが
一目で分かります。Part2 のゴールは、これに近いものを自分たちの JSON
パーサに実装することです。最終的にはこんな出力を目指します。

```
ERROR:
Invalid escaped character: 'g' at line 3, column 8: ·\t[\r"\g"]}]
                                                            ↑
→  Expected a string at line 3, column 6: ··\t[\r"\g"]}
                                                ↑
→  Expected a JSON value at line 3, column 6: ··\t[\r"\g"]}
                                                    ↑
→  Expected an array at line 3, column 4: ··\t[\r"\g"
                                             ↑
```

一番下から読むと「配列を期待していたが」→「その中の JSON 値を期待していたが」
→「文字列を期待していたが」→「エスケープされた文字 `g` は無効」という、
**パースが失敗するまでにたどった文脈の履歴**が積み上がって表示されている
ことが分かります。

## 何を実現したいか

具体的には、以下の3つをエラーメッセージに含めたいです。

1. **エラーの内容**: 何を期待していて、実際は何だったか。
2. **エラーの位置**: 入力の何行目・何列目で起きたか。
3. **エラーの文脈**: JSON 文法上のどの部分(配列、オブジェクトのキー、
   文字列、…)をパースしようとしていて失敗したか。

## 進め方

Part1 で書いたテスト(QuickCheck プロパティ)がここで役立ちます。
「パーサを書き直しても、正しい入力に対しては今まで通り正しくパースできる」
ことを、テストを流しながら保証していきます。作業量は多いですが、
壊れていないことをテストが常に確認してくれるので、安心して進められます。

大きな流れは以下の通りです。

1. **`ParseResult`**: `Maybe` の代わりに「エラーメッセージのリスト」を
   持てる型を用意する。
2. **バックトラッキングの問題**に気づく: `Alternative` (`<|>`) と
   エラー報告は相性が悪いことを実演する。
3. **`Zipper`**: 入力の中で「今どこにいるか」を追跡するデータ構造を導入する。
4. **エラーメッセージに位置情報を載せる**。
5. これらを踏まえて、**すべてのパーサを書き直す**(バックトラッキングでは
   なく先読みを使う形に)。

Part1 とは別のファイル `src/Exercise/Part2/Parser.hs` に、ゼロから
書き直していきます。

## 次へ

[13. ParseResult と Parser1](13-parseresult-and-parser1.md) に進んでください。
