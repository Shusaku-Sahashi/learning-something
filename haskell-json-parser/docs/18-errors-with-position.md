# 18. 位置情報付きエラーメッセージ

対応する実装ファイル: `src/Exercise/Part2/Parser.hs`(セクション `docs/18-...`)

## addPosition: 座標とテキストの抜粋を添える

エラーメッセージの文字列に「何行目・何列目で、周辺のテキストはこう」という
情報を付け加える関数を作ります。

```haskell
addPosition :: String -> TextZipper String -> String
```

出力イメージ(12 や `runParser lookahead ""` などで見た形):

```
Expected a digit, got 'a' at line 1, column 1: abhina
                                                ↑
```

実装方針:

1. `currentPosition` で行番号・列番号を取得する。
2. `Text.Printf.printf` で `"元のエラーメッセージ at line %d, column %d: "`
   という文字列を組み立てる。
3. カーソル周辺のテキスト(前後数文字程度)を切り出す。
   `tzLeft`/`tzRight` から必要な範囲だけ `take`/`drop` する。
4. 3で切り出した文字列を、改行やタブなどが含まれていても崩れないように
   `showCharForErrorMsg`(実装済み)でエスケープ表示に変換する。
5. 2文字目の行の下に、カーソル位置に合わせて `↑` を表示する行を追加する。
   `↑` の位置は「1行目の文字数と同じ数だけスペースを置く」ことで揃えます。

`src/Exercise/Part2/Parser.hs` にすでにある骨組み(`ctxLen`, `showStr` など
の `where` 節)を活用しながら実装してください。難しければ、まず
「位置情報だけ入れて、周辺テキストの抜粋は後回し」のように段階的に
組み立てても構いません。最終的な出力の形は上の例と `runTests`
実行時の出力例を目安にしてください。

## throw と elseThrow

```haskell
parseError :: String -> TextZipper String -> ParseResult a
parseError err zipper = Error [addPosition err zipper]

throw :: String -> Parser String o
throw = Parser . parseError
```

これらはすでに実装されています。`throw "何か理由"` は「現在の位置情報付きで、
指定した理由により必ず失敗するパーサ」です。

```haskell
elseThrow :: Parser String o -> String -> Parser String o
```

`parser \`elseThrow\` "追加のエラーメッセージ"` は「`parser` を実行してみて、
成功したらそのまま結果を返す。失敗したら、その失敗に**さらに1段**、
指定したメッセージ(現在位置つき)を追加してから伝播する」というものです。
12 で見た「複数行にわたるエラーメッセージの積み重ね」は、この
`elseThrow` をパースの各段階(「JSON 値を期待」「配列を期待」「オブジェクトの
キーを期待」…)に挟んでいくことで実現します。

実装方針:

1. `parser` を入力に対して実行する。
2. 成功ならそのまま返す。
3. 失敗(`Error errs`)なら、現在の入力位置に対して
   `addPosition err input` で新しいメッセージを1つ作り、それを既存の
   `errs` の**先頭に**追加した `Error` を返す。

`src/Exercise/Part2/Parser.hs` に実装してください。`ParseResult` の
`Show` インスタンス(13 で読んだもの)が、このリストを**逆順に**
(つまり最後に追加されたものを最初に)表示するようになっていることを
思い出してください。「一番具体的な失敗理由が先頭、一番外側の文脈が
末尾に来るようにリストへ追加していく」という向きに注意してください。

## 動作確認

`addPosition`/`throw`/`elseThrow` の直接的な確認は次のステップの
`lookahead`/`satisfy` の実装後にまとめて行います。ここではコンパイルが
通ることを確認しておいてください。

```bash
cabal build
```

## 次へ

[19. 基本パーサの書き直し](19-basic-parsers-rewrite.md) に進んでください。
