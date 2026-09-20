# ⚙️ 第8章 実践（Example 81–92）

## この章のゴール

IO・可変状態・例外・並行処理・パーサなど、**実際のコード**にプロパティテストを適用します。
そして、ご質問のあった **state machine テスト**をここで扱います。

## IO を含むプロパティ

| API | 使いどころ |
|---|---|
| `ioProperty :: IO prop -> Property` | 単発の IO。短く書ける |
| `monadicIO :: PropertyM IO a -> Property` | 手順が長い、途中で assert したい |

```haskell
-- ioProperty
prop_incrementN :: NonNegative Int -> Property
prop_incrementN (NonNegative n) = ioProperty $ do
  c <- newCounter
  mapM_ (const (increment c)) [1 .. n]
  v <- readCounter c
  pure (v == n)

-- monadicIO
prop_overwrite :: String -> Int -> Int -> Property
prop_overwrite k v1 v2 = monadicIO $ do
  pre (v1 /= v2)                   -- (==>) に相当
  s <- run newStore                -- IO を実行
  run (putKV s k v1)
  run (putKV s k v2)
  got <- run (getKV s k)
  monitor (counterexample ("got = " ++ show got))   -- 情報を足す
  assert (got == Just v2)
```

`monadicIO` の道具：`run` / `assert` / `pre` / `monitor` / `pick`。
（`pick` で生成した値は縮小されません。縮小してほしい値は引数で受け取ること）

**鉄則：毎回まっさらな状態を作る。** テストの実行順に依存するテストは必ずいつか壊れます。

## 例外

| 対象 | 方法 |
|---|---|
| IO の例外 | `try action` |
| 純粋な式の例外 | `try (evaluate expr)` |
| 「落ちないこと」だけ | `total value` |

⚠️ `evaluate` を忘れると捕まりません。

```
try (pure (head []))     -> Right (NOT caught: the thunk escaped)
try (evaluate (head [])) -> Left  (caught: Prelude.head: empty list)
```

また `evaluate` は WHNF（先頭だけ）までしか評価しません。
リストの途中に `error` があると捕まらないので、`total` を使ってください。

**「どの例外が出るか」まで確かめること。**
`SomeException` で受けると、意図しない別のバグで落ちた場合も成功扱いになります。

## 時間

```haskell
prop_collatzAnyInt :: Int -> Property
prop_collatzAnyInt n = within 200000 (collatz n >= 0)   -- 0.2 秒
```

注意：
1. 環境に依存する。CI が遅いと落ちる。余裕は 5〜10 倍
2. 縮小のたびに再実行されるので、縮小も遅くなる
3. 巨大な入力を `forAll` で渡すと、反例が全部印字される。`forAllBlind` + `counterexample` で要約を

## 再現

```haskell
quickCheckWith stdArgs { replay = Just (mkQCGen 42, 0) } prop
```

`replay` は `(乱数生成器, 初期サイズ)` のペアです。**サイズも結果を左右します。**

実務の手順：
1. テストコードで `QC_SEED` を読んで `replay` を設定できるようにする
2. CI のログに使ったシードを必ず出力する
3. 落ちたら `QC_SEED=123456 cabal test` で手元再現

⚠️ シードが同じでも、生成器やプロパティを変えると入力は変わります。
永続的に残したいなら、値そのものを回帰テストに書き留めてください（第9章）。

## 結果をプログラムから扱う

```haskell
r <- quickCheckWithResult stdArgs { chatty = False } prop
isSuccess r          -- 成否
numTests r           -- 実行したテスト数
numShrinks r         -- 縮小の回数
failingTestCase r    -- 反例（[String]）
usedSeed r / usedSize r  -- 再現に使う情報
labels r / tables r  -- classify や tabulate の集計
```

自作のテストランナーを書くときの土台になります。

---

## 🔑 State machine テスト（Example 87–89, 92）

### なぜ「列」が必要なのか

Example 87 では、キューの各操作を**1回だけ**モデルと比べました。
しかしこれでは、**操作の順序でしか出ないバグ**を検出できません。

Example 88 で仕込んだバグは、`pop` が内部の表現不変条件を壊すものです。

| テスト | 結果 |
|---|---|
| 1回だけ `pop` してモデルと比較 | **PASS** |
| コマンド列（`Push, Push, Pop, Pop`） | **FAIL** |

なぜか：`pop` を1回呼ぶだけなら正しい値を返します。壊れるのは**内部状態**です。
抽象化関数 `toList` はその状態でも正しい内容を返すので、違いが出ません。
ところが**次に** `pop` を呼ぶと `Nothing` を返してしまいます。

### 構成要素（どのライブラリでも同じ）

| # | 要素 | 役割 |
|---|---|---|
| 1 | `Cmd` | 操作を表すデータ型 |
| 2 | `Model` | 単純で明らかに正しい状態表現 |
| 3 | `stepModel` | モデル上でコマンドを実行 |
| 4 | `stepImpl` | 実装上でコマンドを実行 |
| 5 | `Obs` | 外から観測できる値 |
| 6 | プロパティ | コマンド列を両方に流し、観測列を比較 |
| 7 | `shrink` | コマンド列を短くする |

### 出力例（Example 88）

```
*** Failed! Falsified (after 18 tests and 7 shrinks):
[Push 0,Push 0,Pop,Pop]
    Push 0     impl=OUnit              model=OUnit               state=Queue [0] []
    Push 0     impl=OUnit              model=OUnit               state=Queue [0] [0]
    Pop        impl=OPopped (Just 0)   model=OPopped (Just 0)    state=Queue [] [0]
    Pop        impl=OPopped Nothing    model=OPopped (Just 0)     <-- MISMATCH  state=Queue [] [0]
```

### 省略してはいけない2つのこと

1. **トレースを `counterexample` で出す。** これがないと反例を見ても何が起きたか分かりません
2. **`forAllShrink` を使う（`forAll` ではなく）。**
   Example 92 では、`forAll` のままだと 16 個のコマンド列がそのまま出て読めませんでした。
   `forAllShrink` に変えると 4 個まで縮みます

さらに、コマンドの分布を `cover` で守ってください。
キーの範囲が広すぎて「キャッシュヒットが一度も起きない」といった事態に気づけません。

### State machine テストが便利な場面

- **バグが「操作の順序」でしか出ない**とき
  （`insert → evict → insert → lookup` で壊れるキャッシュなど）
- **対象が内部状態を持つ**とき
  （可変参照、コネクションプール、ファイルハンドル、ステートフルな API）
- **「正しい実装」を単純なモデルで書ける**とき
  （高速な本番実装 vs `Data.Map` などの素朴な参照実装）
- **並行処理の線形化可能性**を確かめたいとき

### 並行版への拡張

1. コマンド列を2本（または3本）生成する
2. それぞれ別スレッドで実行し、観測結果を記録する
3. 2本を「交互に並べ替えた」すべての逐次実行を試す
4. どれか1つでも観測結果に一致すれば OK

交互の並べ替えは組み合わせ爆発するので、列は 3〜5 個に保ちます。
`quickcheck-state-machine` の並列テストがこれにあたります。

---

## 並行処理のテスト（Example 89）

並行バグは「たまたま起きる」ので、素朴に書くと再現しません。
Example 89 では `yield` を挟んで、確実に競合が起きるようにしています。

```haskell
incUnsafe r = do
  v <- readIORef r
  yield                     -- ここで他スレッドに切り替わる
  writeIORef r (v + 1)
```

結果：20 スレッドが1回ずつ増やして、カウンタは **2**。

現実：
1. 再現性がない。長時間回すしかない
2. 「最悪のスケジュール」を再現する工夫が要る（`yield`、`threadDelay`、`-threaded`、`dejafu`）
3. 検出しやすいのは「不変条件が壊れる」タイプ（合計が保存される、件数が一致する）

## Example 一覧

| # | 内容 |
|---|---|
| [81](../examples/Example81.hs) | `ioProperty`。IORef カウンタ |
| [82](../examples/Example82.hs) | `monadicIO`。`run` / `assert` / `pre` / `monitor` / `pick` |
| [83](../examples/Example83.hs) | 例外のテスト。遅延評価の罠 |
| [84](../examples/Example84.hs) | `within`。タイムアウトと性能 |
| [85](../examples/Example85.hs) | `replay` とシード。`unGen` で生成の決定性を確認 |
| [86](../examples/Example86.hs) | `Result` をプログラムから扱う。自作ランナー |
| [87](../examples/Example87.hs) | **モデルベーステスト入門**。可換図式 |
| [88](../examples/Example88.hs) | **state machine テスト**。列でしか出ないバグ |
| [89](../examples/Example89.hs) | 並行処理。競合状態の検出 |
| [90](../examples/Example90.hs) | パーサと pretty printer の往復（優先順位と括弧） |
| [91](../examples/Example91.hs) | 二分探索木を丸ごと検証（23 プロパティ） |
| [92](../examples/Example92.hs) | **総合演習**：LRU キャッシュの state machine テスト |

## 次へ

→ [第9章 プロジェクトでの運用](./09-project.md)
