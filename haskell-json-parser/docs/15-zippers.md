# 15. Zipper という考え方

対応する実装ファイル: `src/Exercise/Part2/Parser.hs`(セクション `docs/15-...`)

## 位置情報をどう追跡するか

エラーメッセージに「何行目・何列目」を含めるには、パーサが**入力のどこを
読んでいるか**を常に把握している必要があります。ありがちな方法は
「状態(現在の行・列)を横に持ち回る」ことです(`StateT` モナド変換子を
使うのが定番です)。しかし今回はあえて、あまり日常的には使わない
**Zipper** というデータ構造を使います。

## Zipper とは

Wikipedia の Zipper の項目を要約すると:

> Zipper とは、集約的なデータ構造を「任意の場所を自由に行き来しながら
> 更新できる」ように表現する技法である。

Zipper には常に**フォーカス(焦点、カーソル)**があり、それが「今、
自分たちがいる場所」です。そして残りの構造を、フォーカスから移動しやすい
形で持っています。

図解: [List Zipper の可視化](https://claude.ai/code/artifact/f1587504-acff-4abd-9aa9-2102cef874a8#list-zipper)

まずは一番シンプルな「リストの Zipper」で考え方に慣れます。

```haskell
data ListZipper a
  = ListZipper
  { lzLeft :: [a],
    lzFocus :: a,
    lzRight :: [a]
  }
  deriving (Show)
```

リスト `[1,2,3,4,5,6,7,8,9]` の `4` に注目しているときの `ListZipper` は:

```haskell
ListZipper { lzLeft = [3,2,1], lzFocus = 4, lzRight = [5,6,7,8,9] }
```

`lzLeft` は**フォーカスから見て左側の要素を、フォーカスに近い順に**並べた
リストです(`[3,2,1]` であって `[1,2,3]` ではないことに注意)。これにより
「フォーカスをひとつ左に動かす」操作が、`lzLeft` の**先頭を取り出すだけ**の
軽い操作になります。

```haskell
lzMoveRight :: ListZipper a -> ListZipper a
lzMoveRight (ListZipper l f []) = ListZipper l f []
lzMoveRight (ListZipper l f (x : xs)) = ListZipper (f : l) x xs
```

「右に動く」= 「今のフォーカス `f` を左リストの先頭に積み、右リストの
先頭 `x` を新しいフォーカスにする」。右リストが空ならこれ以上動けないので
そのまま返します(末尾で止まる)。`lzMoveRight` を
`src/Exercise/Part2/Parser.hs` に実装してください(すでに実装されている
`list2zipper`/`zipper2list` と見比べると、この「反転して持つ」設計の
意図が掴みやすいはずです)。

```haskell
lzMoveLeft :: ListZipper a -> ListZipper a
```

`lzMoveRight` の左右を逆にしたものです。実装してください。

## なぜこの持ち方が嬉しいのか

素朴に「今どこにいるか」をインデックス(添字)で管理する場合、
「1つ進む/戻る」たびに、リストの先頭から数え直す(あるいは
`!!` でアクセスする)必要があり、リストが長いほど遅くなります。
Zipper なら「フォーカスの隣を左右のリストの先頭として直接持っている」ので、
移動は常に一定時間で済みます。パーサが1文字ずつ入力を読み進める処理と、
この「隣に移動する」操作の相性は非常に良いです。

## 動作確認

```
ghci> import Exercise.Part2.Parser
ghci> import qualified Data.List.NonEmpty as NEL
ghci> lz = list2zipper (NEL.fromList [1..9])
ghci> lz
ListZipper {lzLeft = [], lzFocus = 1, lzRight = [2,3,4,5,6,7,8,9]}
ghci> lzMoveRight (lzMoveRight (lzMoveRight lz))
ListZipper {lzLeft = [3,2,1], lzFocus = 4, lzRight = [5,6,7,8,9]}
ghci> lzMoveLeft (lzMoveRight (lzMoveRight (lzMoveRight lz)))
ListZipper {lzLeft = [2,1], lzFocus = 3, lzRight = [4,5,6,7,8,9]}
```

`Data.List.NonEmpty` は「空になりえないリスト」を表す型です
(`NEL.fromList` は空リストを渡すと実行時エラーになります)。
`ListZipper` は常にフォーカスを1つ持つ必要があるため、空リストからは
作れない、ということが型のレベルで表現されています。

## 次へ

[16. Text Zipper](16-text-zipper.md) に進んでください。
