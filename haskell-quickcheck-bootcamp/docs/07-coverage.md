# 📊 第7章 分布とカバレッジ（Example 71–80）

## この章のゴール

「テストは通っているが、実は何も検査していない」状態を**機械的に**防げるようになります。

## 測る道具

| API | 役割 | 合計 |
|---|---|---|
| `collect x prop` | 値そのものの分布 | 100% |
| `label s prop` | 常にそのラベルを記録（排他的カテゴリ） | 100% |
| `classify cond s prop` | 条件が真のときだけ記録 | 重なる／届かない |
| `tabulate name [s] prop` | 名前付きの表。1件から複数記録できる | — |

```haskell
prop_classify :: [Int] -> Property
prop_classify xs =
  classify (null xs)        "empty"     $
  classify (length xs > 10) "long"      $
    reverse (reverse xs) == xs
```

一番よく使うのは `classify` です。「この分岐に到達しているか？」を確かめる用途が圧倒的に多いからです。

## 守る道具

| API | 役割 |
|---|---|
| `cover pct cond s prop` | ラベルごとの下限（既定では**警告のみ**） |
| `coverTable name [(s,pct)] prop` | 表全体の下限 |
| `checkCoverage prop` | 下限を満たさなければ**失敗させる** |

```haskell
prop_guarded :: Property
prop_guarded =
  checkCoverage $
  forAll genPayment $ \p ->
    cover 20 (isCash p)  "cash" $
    cover 20 (isCard p)  "card" $
      fee p >= 0
```

`checkCoverage` は判定がつくまでテスト回数を自動で増やします。
出力のテスト回数が 100 ではなく 400 や 1600 になるのは正常な動作です。

## 事故の実演（Example 77）

「在庫あり優先、そのあと価格順」で並べる関数に、バグを1つ仕込んで、
3つの生成器で同じプロパティを回します。

| 生成器 | 結果 |
|---|---|
| 1. 全商品が在庫あり (`pure True`) | **PASS**（バグが一度も踏まれない） |
| 2. 5% だけ在庫なし | FAIL（14 テスト目） |
| 3. 半々、長さ 2–10 | FAIL（1 テスト目） |

生成器 1 の出力には `"has an out-of-stock item"` の行が**そもそも出てきません**
（QuickCheck は 0% のラベルを表示しない）。
「あるはずのラベルが無い」ことに気づけるかが分かれ目です。

そこで `cover` を足すと：

```
*** Failed! Insufficient coverage (after 100 tests):
Only 0% has BOTH in and out of stock, but expected 30%
```

**「試していない」ことが、自動でテスト失敗になります。**

## 分布を直す技法カタログ（Example 78）

実測結果（2000 回中）：

| 技法 | before | after |
|---|---|---|
| 1. `frequency` の重みを変える | Error 42 | Error 496 |
| 2. 入力同士に相関を持たせる | 49 | 2000 |
| 3. 境界値を明示的に混ぜる | 39 | 187 |
| 4. 狙い撃ち生成器 (`x == y`) | 2 | 2000 |
| 5. サイズを上げる（長さ ≥ 50） | 0 | 1504 |
| 6. 候補集合を小さくする（重複） | 0（Int 全域） | 1719（`choose (0,5)`） |
| 7. 構造から作る（合計が N） | — | 必ず成立 |

### 技法6 は特に見落とされます

キャッシュ・辞書・集合など「同じキーが来たとき」のバグは、
値の範囲が広いままだと**まず出ません**。

- `choose (minBound, maxBound)` → 重複 0 / 2000
- `arbitrary`（既定、サイズ依存で小さい） → 1324 / 2000
- `choose (0, 5)` → 1719 / 2000

自作の ID 型や UUID 風の生成をすると、衝突時の挙動が一度も試されません。
**テスト用には、わざと狭い範囲の生成器を用意してください。**

## しきい値の決め方

**必ず実測してから決めます。** 実測値のおよそ半分〜2/3 を下限にします。

Example 79 では `cover 5 (length xs == 1) "singleton"` と書いて失敗しました。
実測は 4% 前後だったためです。2% が妥当でした。

## 運用の提案：生成器ガードプロパティ

対象のロジックは一切テストせず、**「生成器がまだ健全か」だけ**を見るプロパティを1本立てます。

```haskell
prop_generatorHealthy :: Property
prop_generatorHealthy =
  checkCoverage $
  forAll myGen $ \x ->
    cover 20 (isCaseA x) "case A" $
    cover 20 (isCaseB x) "case B" $
      True
```

CI に置いておけば、誰かが生成器を変えたときに、ここが落ちます。

## 手順

1. 素朴な生成器で書く
2. `tabulate` / `classify` で分布を測る
3. 届いていない分岐を見つける
4. 生成器を設計し直す（技法カタログ）
5. `cover` + `checkCoverage` で固定する
6. **そこで初めて、本来のプロパティを書く**

STEP 2 を飛ばすと、「通っているのに何も検査していないテスト」が静かに積み上がります。

## Example 一覧

| # | 内容 |
|---|---|
| [71](../examples/Example71.hs) | `collect` |
| [72](../examples/Example72.hs) | `label` と `classify` の違い |
| [73](../examples/Example73.hs) | `tabulate`。遷移の集計も |
| [74](../examples/Example74.hs) | `cover`。足りないと言われたら生成器を直す |
| [75](../examples/Example75.hs) | `checkCoverage`。生成器の劣化を CI で検出 |
| [76](../examples/Example76.hs) | `coverTable` |
| [77](../examples/Example77.hs) | **事故の完全な実演**。この章で一番大事 |
| [78](../examples/Example78.hs) | 分布を直す技法カタログ（7種、実測付き） |
| [79](../examples/Example79.hs) | 測定ヘルパーを自作する。生成器ガード |
| [80](../examples/Example80.hs) | **総合演習**：API ハンドラの入力分布を設計する |

## 次へ

→ [第8章 実践](./08-practice.md)
