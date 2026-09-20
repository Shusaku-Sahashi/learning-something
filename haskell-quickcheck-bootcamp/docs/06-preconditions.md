# 🚧 第6章 前提条件と Modifier（Example 59–70）

## この章のゴール

「この条件のときだけ成り立つ」性質を、**捨てる入力をゼロにして**書けるようになります。

## `(==>)` は「捨てる」だけ

```haskell
prop_headOfSorted :: [Int] -> Property
prop_headOfSorted xs = not (null xs) ==> head (mySort xs) === minimum xs
```

条件が False の入力は捨てられ、テスト回数に数えられません。

```
+++ OK, passed 100 tests; 12 discarded.
           ^^^ 条件を満たした     ^^^ 捨てられた
```

**重要：`(==>)` は「条件を満たす入力を作る」わけではありません。**
条件が厳しいと、いくら生成しても通らず、テストが成立しなくなります。

## 落とし穴1：Gave up

```
*** Gave up! Passed only 12 tests; 1000 discarded tests.
```

`maxDiscardRatio`（既定 10）を超えて捨てると諦めます。
100 × 10 = 1000 個捨てた時点で打ち切りです。

実測（Example 60）：ランダムなリストが偶然ソート済みである確率

| 長さ | 確率 |
|---|---|
| 0, 1 | 100% |
| 2 | 51% |
| 3 | 17% |
| 5 | 1% |
| 8 | 0%（2000 回引いて 0 件） |

## 落とし穴2：Gave up しなくても分布が歪む

「2つのリストの長さが等しい」という条件で絞ると、
長さ 0 と 1 が圧倒的に多くなります（短いほど偶然一致しやすい）。
その結果、**長いリストはほとんど試されません。**

`(==>)` を書いたら、必ず `collect` や `classify` で分布を確認してください（第7章）。

## 落とし穴3：条件が増えると掛け算で落ちる

実測（Example 68、5000 回中の通過数）：

| 条件 | 通過 |
|---|---|
| `a > 0` | 2430 |
| `a > 0 && b > 0` | 1166 |
| `a > 0 && b > 0 && c > 0` | 577 |
| `... && a < b` | 316 |
| `... && a < b && b < c` | 100 |

条件が 5 つある仕様は珍しくありません。そのまま書けば、ほぼ確実に Gave up します。

## 対処の優先順位

1. **標準 Modifier で書けないか**（既製品があるなら最速）
2. **生成器を書き直して、条件を満たす値を直接作る**（これが本命）
3. `maxDiscardRatio` を上げる（最後の手段。遅いだけ）

## 標準 Modifier 一覧

### 数値

| Modifier | 意味 |
|---|---|
| `Positive a` | 0 より大きい |
| `NonNegative a` | 0 以上 |
| `Negative a` | 0 より小さい |
| `NonPositive a` | 0 以下 |
| `NonZero a` | 0 でない |
| `Small a` | 小さい値だけ |
| `Large a` | 型の範囲全体に広がる |

### リスト

| Modifier | コンストラクタ | 意味 |
|---|---|---|
| `NonEmptyList a` | `NonEmpty xs` | 空でないリスト |
| `OrderedList a` | `Ordered xs` | 昇順のリスト |
| `SortedList a` | `Sorted xs` | 昇順のリスト |
| `InfiniteList a` | `InfiniteList xs _` | 無限リスト |

### 文字列

| Modifier | 意味 |
|---|---|
| `ASCIIString` | ASCII 文字だけ |
| `PrintableString` | 表示可能な文字だけ |
| `UnicodeString` | Unicode 全域（絵文字や制御文字も） |

### 制御

| Modifier | 意味 |
|---|---|
| `Blind a` | 値を表示しない |
| `Fixed a` | 縮小しない |
| `Shrink2 a` | 2段階まとめて縮小 |

⚠️ コンストラクタ名が型名と違うものがあります（`NonEmptyList` → `NonEmpty`、`OrderedList` → `Ordered`）。

### Modifier を使う利点

1. 入力が捨てられないので、テスト回数がそのまま有効な試行数になる
2. 分布が歪まない
3. **縮小も不変条件を守る**（`Positive 5` を縮めても `Positive 0` にはならない）
4. 型を見れば前提条件が分かる（ドキュメントとして機能する）

## 条件を生成器に移す（Example 67 のリファクタ手順）

実測結果：

| 段階 | 結果 |
|---|---|
| Step 0: 全部 `(==>)` | **GAVE UP** after 11, discarded 1000 |
| Step 1: 標準 Modifier で置換 | passed 100, discarded 167 |
| Step 2: 全部生成器に移す | passed 100, **discarded 0** |

手順：

1. まず動くテストを `(==>)` で書く。速度は気にしない
2. 標準 Modifier で置き換えられる条件を置き換える
3. 残った条件を生成器に移す。専用の `newtype` を作る
4. `shrink` も書く。不変条件を守るように
5. **捨てる数が 0 になったことを確認する**
6. そこで初めて、細かい性質を書き足していく

## 条件の型 → 対処の型

| 条件 | 対処 |
|---|---|
| 正の数 | `Positive` |
| 空でない | `NonEmptyList` |
| 昇順 | `OrderedList`、または生成してから `sort` |
| `a < b` | `b` を `a` に依存させて生成する（`do` 記法） |
| 重複なし | `nub` してから使う、または `shuffle` + `take` |
| 合計が N | N を先に決めて、分割を生成する |
| 区間が重ならない | 時刻を昇順に並べてペアにする（Example 70） |

## `(==>)` を使ってよい場面

| 捨てる割合 | 判断 |
|---|---|
| 10% 未満 | そのままでよい |
| 10–50% | 気になるなら直す。CI が遅いなら直す |
| 50% 超 | 直す |
| Gave up | **必ず直す** |

「捨てる割合」は `quickCheck` の出力に必ず表示されます。
`+++ OK, passed 100 tests; 37 discarded.` の `37 discarded` を毎回見る習慣をつけてください。

## 自作 Modifier

`newtype` + `Arbitrary` インスタンスだけです。

```haskell
newtype Percent = Percent Int deriving (Show, Eq)

instance Arbitrary Percent where
  arbitrary = Percent <$> choose (0, 100)
  shrink (Percent n) = [ Percent n' | n' <- shrink n, n' >= 0, n' <= 100 ]
```

チェックリスト：
1. `arbitrary` が不変条件を守るか
2. `shrink` が不変条件を守るか
3. `shrink` が自分自身を返さないか
4. 「作れない値」がないか（境界値に到達できるか）

## プロパティ全体を修飾する道具

| API | 役割 |
|---|---|
| `withMaxSuccess n prop` | このプロパティだけテスト回数を変える |
| `once prop` | 1回だけ実行（具体例のテスト） |
| `again prop` | `once` を打ち消す |
| `mapSize f prop` | サイズパラメータを変換 |
| `expectFailure prop` | 「失敗するはず」を表明 |
| `within µs prop` | タイムアウト |
| `discard` | この入力を捨てる |

⚠️ `mapSize` はプロパティ**全体**を包んでください。
関数の内側に書くと、引数はもう生成済みなので効きません。

```haskell
-- ✗ 効かない
prop xs = mapSize (const 3) (length xs <= 3)
-- ○ 効く
prop = mapSize (const 3) (\xs -> length (xs :: [Int]) <= 3)
```

## Example 一覧

| # | 内容 |
|---|---|
| [59](../examples/Example59.hs) | `(==>)` の基本 |
| [60](../examples/Example60.hs) | **Gave up**。ソート済みリストの確率を実測 |
| [61](../examples/Example61.hs) | 条件で絞ると分布が歪む |
| [62](../examples/Example62.hs) | 数値の Modifier |
| [63](../examples/Example63.hs) | リストと文字列の Modifier |
| [64](../examples/Example64.hs) | `discard` を直接使う |
| [65](../examples/Example65.hs) | 自作 Modifier を作る（5パターン） |
| [66](../examples/Example66.hs) | プロパティ全体を修飾する道具 |
| [67](../examples/Example67.hs) | **リファクタ実例**：Step 0 → Step 2 |
| [68](../examples/Example68.hs) | 条件が複数あるとき。確率の実測 |
| [69](../examples/Example69.hs) | `(==>)` を使ってよい場面。捨てる割合の測り方 |
| [70](../examples/Example70.hs) | **総合演習**：予約システムの入力を設計する |

## 次へ

→ [第7章 分布とカバレッジ](./07-coverage.md)
