# 16. Text Zipper

対応する実装ファイル: `src/Exercise/Part2/Parser.hs`(セクション `docs/16-...`)

## テキストを2次元として捉える

パーサへの入力は `String` という1次元の文字の並びですが、エラー報告の
ためには「何行目・何列目」という**2次元の位置**を扱いたいわけです。
そこで入力を「行のリスト」として捉え直し、「今いる行」だけをさらに
文字単位で左右に割った Zipper を作ります。

図解: [Text Zipper の可視化](https://claude.ai/code/artifact/f1587504-acff-4abd-9aa9-2102cef874a8#text-zipper)

```haskell
data TextZipper a
  = TextZipper
  { tzLeft :: a,
    tzRight :: a,
    tzAbove :: [a],
    tzBelow :: [a]
  }
```

- `tzAbove`: カーソルより**上の行**を、リストの `ListZipper` と同じ考え方で
  「カーソルに近い行から順」に並べたもの。
- `tzBelow`: カーソルより**下の行**を、上から順に並べたもの。
- `tzLeft`/`tzRight`: カーソルが**今いる行**を、カーソル位置で左右に
  割ったもの。`tzLeft` は「カーソルに近い文字が先頭」(`ListZipper` の
  `lzLeft` と同じ向き)、`tzRight` は「カーソルから見て右の文字がそのままの
  順」です。

`a` が型変数になっているのは、`String`(＝`[Char]`)の Zipper としても、
将来別の「行の型」に対しても使える汎用的な定義にするためです
(実際に使うときはすべて `TextZipper String` です)。

## 行分割: lines

```haskell
lines :: String -> [String]
lines = (split . dropFinalBlank . keepDelimsR . onSublist) "\n"
```

標準ライブラリの `Prelude.lines` は改行文字を**取り除いてから**分割します
(`"a\nb"` → `["a", "b"]`)。しかし今回は「行の中に改行文字があるかどうか」
自体もエラーメッセージ生成で使いたい(例えば JSON 文字列の途中に
改行が来たら不正、という判定に関わる)ため、`Data.List.Split` パッケージの
関数を組み合わせて、**改行文字を残したまま**分割する自前の `lines` を
用意しています(`"a\nb"` → `["a\n", "b"]`)。これは既に実装済みで、
学習者が実装する対象ではありません(パッケージの細かい API を覚える
必要はありません。「標準の `lines` と挙動が違う」という事実だけ
押さえておいてください)。

## 現在位置と現在の文字

```haskell
textZipper :: [String] -> TextZipper String
textZipper [] = TextZipper "" "" [] []
textZipper (first : rest) = TextZipper "" first [] rest

currentPosition :: TextZipper String -> (Int, Int)
currentPosition zipper =
  (length (tzAbove zipper) + 1, length (tzLeft zipper) + 1)
```

`textZipper` (実装済み) は「行のリスト」から「最初の行にカーソルがある
初期状態の `TextZipper`」を作ります(`tzLeft` は空、`tzRight` が最初の行
まるごと)。`currentPosition` は「上にある行の数 + 1」が行番号、
「左にある文字数 + 1」が列番号、というだけの単純な計算です。

```haskell
currentChar :: TextZipper String -> Maybe Char
```

「カーソルの右にある文字」= `tzRight` の先頭です。`tzRight` が空なら
`Nothing`(入力の末尾にいる)。実装してください。

## moveByOne: 1文字進む

```haskell
moveByOne :: TextZipper String -> TextZipper String
```

3つの場合分けが必要です。

1. **行の途中にいる**(`tzRight` が空でない): `tzRight` の先頭文字を
   `tzLeft` の先頭に移す(`ListZipper` の `lzMoveRight` と同じ操作を
   1行の中でやるだけ)。
2. **行末にいるが、入力の末尾ではない**(`tzRight` は空だが `tzBelow` が
   空でない): 今の行(`tzLeft` を逆順にしたもの、つまり行頭から見た形)を
   `tzAbove` に積み、`tzBelow` の先頭の行を取り出して新しい「今の行」
   ―― つまり `tzRight` にする。`tzLeft` は空に戻す(次の行の先頭にいる
   ため)。
3. **入力の末尾にいる**(`tzRight` も `tzBelow` も空): 何もしない
   (これ以上進めない)。

`src/Exercise/Part2/Parser.hs` に実装してください。レコード更新構文
(`zipper { フィールド名 = 新しい値, ... }`)を使うと簡潔に書けます。

```haskell
move :: TextZipper String -> TextZipper String
move zipper =
  let zipper' = moveByOne zipper
   in case currentChar zipper' of
        Just _  -> zipper'
        Nothing -> moveByOne zipper'
```

これは実装済みです。`moveByOne` を2回呼ぶことがある理由は、行の区切りが
`"...\n"` のように改行文字を**含んだまま**保持されているためです。行末の
`\n` の直後にいる状態(`currentChar` が `Nothing` になる、実際にはまだ
その行の中)を飛び越して、次の行の最初の**実際の文字**まで進めるように
なっています。

```haskell
moveBackByOne :: TextZipper String -> TextZipper String
```

`moveByOne` の逆で、1文字戻ります。場合分けも `moveByOne` を左右反転
させたものです(行の途中なら1文字戻す。行頭かつ最初の行でなければ
上の行の末尾に移る。入力の先頭なら何もしない)。実装してください。

## 動作確認

```
ghci> import Exercise.Part2.Parser
ghci> tz = textZipper (lines "some\nnext\n\nmore")
ghci> tz
TextZipper{left="", right="some\n", above=[], below=["next\n","\n","more"]}
ghci> currentPosition tz
(1,1)
ghci> currentChar tz
Just 's'
ghci> f `times` n = (!! n) . iterate f
ghci> moveByOne `times` 4 $ tz
TextZipper{left="emos", right="\n", above=[], below=["next\n","\n","more"]}
ghci> moveByOne `times` 6 $ tz
TextZipper{left="", right="next\n", above=["\nemos"], below=["\n","more"]}
```

4文字進んだ時点(`emos`/`\n`)から、6文字目でちょうど次の行 `next\n` の
先頭に移っていること(`tzAbove` に前の行がまるごと積まれていること)を
確認してください。

## 次へ

[17. Zipper 対応版 Parser](17-zippered-parser.md) に進んでください。
