# 📘 第1章 はじめてのプロパティ（Example 01–10）

## この章のゴール

- プロパティテストが何をするものか、体で理解する
- `quickCheck` の出力を正確に読めるようになる
- 失敗したときに原因を追うための道具を一通り知る

## 単体テストとの違い

単体テストは「自分が思いついた入力」を試します。
プロパティテストは「入力を考えるのをやめて、性質だけ書き、入力は機械に探させる」やり方です。

```haskell
-- 単体テスト: 具体例
merge [1,3] [2,4] == [1,2,3,4]

-- プロパティ: どんな入力でも成り立つはずのこと
merge (sort xs) (sort ys) == sort (xs ++ ys)
```

Example 03 では、同じバグ入り関数に対して両方を書いています。
単体テストは 4 つとも通り、プロパティは一発で落ちます。

## Example 一覧

| # | 内容 |
|---|---|
| [01](../examples/Example01.hs) | 最初のプロパティ。`quickCheck` の基本形 |
| [02](../examples/Example02.hs) | 失敗したときの出力の読み方（`after N tests and M shrinks`） |
| [03](../examples/Example03.hs) | 単体テストとプロパティの違いを、同じバグで比較 |
| [04](../examples/Example04.hs) | `Bool` と `Property`、`Testable` クラス |
| [05](../examples/Example05.hs) | `(===)` を使うと差分が見える |
| [06](../examples/Example06.hs) | **型注釈が要る理由**。`()` に defaulting される罠 |
| [07](../examples/Example07.hs) | `verboseCheck` で生成値を覗く |
| [08](../examples/Example08.hs) | `quickCheckWith` と `Args`（`maxSuccess` / `maxSize` など） |
| [09](../examples/Example09.hs) | `counterexample` で反例に情報を足す |
| [10](../examples/Example10.hs) | `(.&&.)` `(.||.)` `conjoin` `disjoin` |

## 出力の読み方

```
*** Failed! Falsified (after 6 tests and 5 shrinks):
[0,1]
```

- `after 6 tests` … 6 個目の入力で初めて False になった
- `and 5 shrinks` … そこから 5 回「縮小」して、もっと小さい反例にたどり着いた
- `[0,1]` … 最終的な反例

最初に見つかる反例は `[3,-7,0,12,-2]` のようなゴミ混じりの値ですが、
QuickCheck は自動でそれを削って `[0,1]` という「本質だけ残した」反例にします。
この**縮小（shrinking）**が QuickCheck の生命線です（第5章）。

## 最重要の落とし穴：型が `()` に落ちる

```haskell
-- これは「100 tests passed」と出るが、実は [(),(),()] しか試していない
quickCheck (\xs -> reverse (reverse xs) == xs)
```

多相なプロパティを型注釈なしで渡すと、`()` に defaulting されることがあります。
`()` の値は `()` ただ 1 つなので、何も検査していません。

**対策：プロパティには必ずトップレベルの型シグネチャを付ける。**

```haskell
prop_reverseTwice :: [Int] -> Bool
prop_reverseTwice xs = reverse (reverse xs) == xs
```

「テストが一瞬で通るのにバグが見つからない」ときは、まずこれを疑ってください。

## この章で覚える API

| API | 役割 |
|---|---|
| `quickCheck` | プロパティを 100 回試す |
| `quickCheckWith stdArgs{..}` | 件数やサイズを変える |
| `verboseCheck` | 生成値を 1 件ずつ表示 |
| `(===)` `(=/=)` | 差分が見える比較 |
| `counterexample` | 反例に情報を足す |
| `(.&&.)` `(.||.)` | 条件の合成 |
| `conjoin` `disjoin` | 条件リストの合成 |

## 演習

1. Example 03 の `merge` のバグを直し、プロパティが通ることを確認する
2. Example 05 の `snocBuggy` を直す。`(==)` 版と `(===)` 版の出力の差を見比べる
3. `quickCheckWith stdArgs { maxSuccess = 10000 }` で Example 02 を実行し、反例が変わるか見る

## 次へ

→ [第2章 プロパティの見つけ方](./02-finding-properties.md)
