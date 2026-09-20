# ✂️ 第5章 縮小 shrinking（Example 47–58）

## この章のゴール

反例を「読める大きさ」まで縮められるようになります。
そして、縮小が引き起こす**3つの典型的な事故**を避けられるようになります。

## なぜ必要か

```
# shrink なし
*** Failed! Falsified (after 6 tests):
NoShrinkList [3,-3,-5,-4,5]
  -> どの要素が原因か分からない

# shrink あり
*** Failed! Falsified (after 4 tests and 2 shrinks):
[1,2]
  -> 「正の数が先頭にあって、後ろにもっと大きい数がある」と一目で分かる
```

実務では、生の反例は数十要素のリストや深くネストした JSON になります。
縮小がないと、そこから原因を読み取るのは現実的ではありません。

## 契約は2つだけ

```haskell
shrink :: a -> [a]   -- 「この値より小さい候補たち」
```

1. **返す値は元の値より厳密に小さいこと**（破ると無限ループ）
2. **有限のリストを返すこと**

## 縮小アルゴリズム（貪欲法）

```
current = 最初に見つかった反例
loop:
  for candidate in shrink current:
    if property(candidate) は失敗する:
      current = candidate
      goto loop          -- 見つけた時点で、残りの候補は試さない
  return current
```

**最初に失敗した候補を即座に採用します。**
だから `shrink` が返すリストの**順番**が結果を左右します。
「大きく縮む候補を先に置く」のが鉄則です。

最小の反例は**保証されません**（Example 55 で局所最小の実例を見ます）。

## 書き方のテンプレート

```haskell
-- 積型
shrink (C a b c) =
  [ C a' b  c  | a' <- shrink a ] ++
  [ C a  b' c  | b' <- shrink b ] ++
  [ C a  b  c' | c' <- shrink c ]

-- または（フィールドが多いとき）
shrink (C a b c) = [ C a' b' c' | (a',b',c') <- shrink (a,b,c) ]

-- 和型：単純なコンストラクタへの変換を先に置く
shrink (Rect w h) = [ Square w, Square h ] ++ [ Rect w' h | w' <- shrink w ] ++ ...

-- 再帰型：部分構造そのものを候補に入れる（これが一番効く）
shrink (Add a b) = [ a, b ] ++ [ Lit 0 ] ++ [ Add a' b | a' <- shrink a ] ++ ...

-- newtype：不変条件で filter する
shrink (Score n) = [ Score n' | n' <- shrink n, n' >= 0, n' <= 100 ]
```

## 自動導出：`genericShrink`

```haskell
{-# LANGUAGE DeriveGeneric #-}
data Config = Config { .. } deriving (Show, Eq, Generic)

instance Arbitrary Config where
  arbitrary = ...
  shrink    = genericShrink
```

再帰型では「部分構造そのもの」も候補に出してくれるので強力です。

**使ってよい場合**：型に不変条件がない（どんなフィールドの組み合わせでも有効）。
**使ってはいけない場合**：型に不変条件がある。`genericShrink` は不変条件を知りません。

## 事故1：shrink が不変条件を壊す

第5章で一番ハマるところです。「生成器は正しいのに、縮小するとありえない値になる」。

```haskell
-- ★ 壊れる：lo と hi を独立に縮めるので lo > hi が生まれる
shrink = genericShrink

-- ○ 対策A：不変条件で filter する
shrink r = [ r' | r' <- genericShrink r, validRange r' ]

-- ○ 対策B：スマートコンストラクタで直す
shrink (Range lo hi) = [ mkRange lo' hi' | (lo',hi') <- shrink (lo,hi) ]
```

**実害**：壊れた候補が「型として存在しえない値」として報告され、
存在しないバグのデバッグに1時間溶かすことになります。

**必ず書くべきプロパティ：**

```haskell
prop_shrinkPreservesInvariant :: MyType -> Bool
prop_shrinkPreservesInvariant x = all valid (shrink x)
```

## 事故2：shrink が終わらない

| パターン | 例 |
|---|---|
| 自分自身を候補に含める | `shrink (N n) = [N n] ++ ...` |
| 正規化が値を変えない | `shrink (N n) = [ N (max 5 n') \| n' <- shrink n ]`（`n == 5` のとき自分に戻る） |
| 「大きさ」の定義が誤り | `shrink (N xs) = [ N (reverse xs) ]`（往復する） |

**必ず書くべきプロパティ：**

```haskell
prop_shrinkIsSmaller :: MyType -> Bool
prop_shrinkIsSmaller x = x `notElem` shrink x
```

これ1本で上の1・2は検出できます。
ただし `a -> b -> a` のような長さ2の循環は捕まえられません（Example 53 に経路チェックの実装があります）。

⚠️ 壊れた shrink を `quickCheck` でそのままテストすると、
「反例が見つかる → その反例を shrink で縮小しようとする → 無限ループ」で固まります。
`forAll`（縮小しない）か `maxShrinks = 0` を使ってください。

## 事故3：縮小が遅い／効かない

| 症状 | 原因と対策 |
|---|---|
| 縮小が何百ステップもかかる | 「1ずつ減らす」実装になっている。半分にする実装に直す |
| 反例が全然縮まない | `shrink` を定義し忘れ、または `forAll` を使っている（`forAllShrink` に） |
| 途中で止まる | 局所最小（Example 55）。何度か実行してみる |

デバッグの道具：

| API | 役割 |
|---|---|
| `verboseShrinking prop` | 縮小の各ステップを表示 |
| `maxShrinks = N` | 縮小回数を制限（ハング時の応急処置） |
| `noShrinking prop` | 縮小を無効化 |
| `Blind a` | 値を表示しない（巨大な入力） |
| `Fixed a` | 縮小しない（設定値など） |
| `Shrink2 a` | 2段階まとめて縮小（加速） |

## Example 一覧

| # | 内容 |
|---|---|
| [47](../examples/Example47.hs) | shrink がないとどうなるか |
| [48](../examples/Example48.hs) | 契約とデフォルト実装の挙動（実際の出力付き） |
| [49](../examples/Example49.hs) | 自作型に shrink を書く（積型・和型・newtype） |
| [50](../examples/Example50.hs) | `shrinkList` / `shrinkMap` / `shrinkNothing` などの部品 |
| [51](../examples/Example51.hs) | `genericShrink` |
| [52](../examples/Example52.hs) | **事故1**：不変条件を壊す。実害の実演 |
| [53](../examples/Example53.hs) | **事故2**：終わらない。3パターンと検出方法 |
| [54](../examples/Example54.hs) | 再帰型の shrink。部分構造を候補にする |
| [55](../examples/Example55.hs) | 探索順序と局所最小 |
| [56](../examples/Example56.hs) | 縮小のデバッグ |
| [57](../examples/Example57.hs) | 縮小を制御する道具 |
| [58](../examples/Example58.hs) | **総合演習**：shrink 付きのデータ型を仕上げる |

## この章のまとめ（6点）

1. `Arbitrary` を書いたら `shrink` も書く
2. 不変条件がある型は、縮小候補をスマートコンストラクタで直す
3. 直した結果が元と同じものは除く（無限ループ防止）
4. 次の3つのプロパティを必ず書く
   - `prop_genValid` : 生成器が不変条件を守る
   - `prop_shrinkValid` : 縮小が不変条件を守る
   - `prop_shrinkNoSelf` : 縮小が自分自身を返さない
5. 不変条件がないなら `genericShrink` でよい
6. 縮小が効かないときは `verboseShrinking` で調べる

## 次へ

→ [第6章 前提条件と Modifier](./06-preconditions.md)
