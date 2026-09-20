# 🧪 Haskell QuickCheck ブートキャンプ

QuickCheck をゼロから実務レベルまで積み上げる、**100 本の実行可能な Example** による教材です。

- 📦 依存は **base / containers / QuickCheck だけ**
- ▶️ 全 Example が `runghc ExampleNN.hs` で単体実行できる
- ✅ **100 件すべて実機で実行確認済み**（GHC 9.4.7 / QuickCheck 2.14.3）
- 🏗 第9章では実際に `cabal test` が通るプロジェクトを触る

## 🚀 はじめかた

```bash
# 1. 環境を用意する（詳細は docs/00-setup.md）
ghcup install ghc 9.6.4 && cabal install --lib QuickCheck
# または: sudo apt-get install ghc libghc-quickcheck2-dev

# 2. 動作確認
cd examples && runghc Example01.hs

# 3. 第1章から読み始める
```

→ **[docs/00-setup.md（環境構築と進め方）](./docs/00-setup.md)**

## 📚 章構成

| 章 | 内容 | Example | ドキュメント |
|---|---|---|---|
| 1 | はじめてのプロパティ | 01–10 | [01-first-property.md](./docs/01-first-property.md) |
| 2 | プロパティの見つけ方（9パターン） | 11–22 | [02-finding-properties.md](./docs/02-finding-properties.md) |
| 3 | ジェネレータ入門 | 23–30 | [03-generators.md](./docs/03-generators.md) |
| 4 | 自作型の生成器 | 31–46 | [04-custom-generators.md](./docs/04-custom-generators.md) |
| 5 | 縮小 shrinking | 47–58 | [05-shrinking.md](./docs/05-shrinking.md) |
| 6 | 前提条件と Modifier | 59–70 | [06-preconditions.md](./docs/06-preconditions.md) |
| 7 | 分布とカバレッジ | 71–80 | [07-coverage.md](./docs/07-coverage.md) |
| 8 | 実践（IO・例外・並行・**state machine**） | 81–92 | [08-practice.md](./docs/08-practice.md) |
| 9 | プロジェクトでの運用 | 93–100 | [09-project.md](./docs/09-project.md) |
| — | API 早見表 | — | [99-cheatsheet.md](./docs/99-cheatsheet.md) |

## 🗂 ディレクトリ

```
haskell-quickcheck-bootcamp/
├── README.md             このファイル
├── run-all.sh            全 Example の実行確認スクリプト
├── docs/                 章ごとの解説（日本語）
├── examples/             Example01.hs 〜 Example100.hs
└── project/              第9章で使う、動く cabal プロジェクト
    ├── src/Bootcamp/     ライブラリ本体
    ├── test/Gen/         生成器
    ├── test/Props/       プロパティ（回帰テスト込み）
    └── .github/workflows/ci.yml
```

## 📝 Example 全 100 本

### 第1章 はじめてのプロパティ

| # | 内容 |
|---|---|
| [01](./examples/Example01.hs) | 最初のプロパティ |
| [02](./examples/Example02.hs) | 失敗したときの出力の読み方 |
| [03](./examples/Example03.hs) | 単体テストとプロパティの違い |
| [04](./examples/Example04.hs) | `Bool` と `Property`、`Testable` |
| [05](./examples/Example05.hs) | `(===)` で差分を見る |
| [06](./examples/Example06.hs) | 型注釈が要る理由（`()` への defaulting） |
| [07](./examples/Example07.hs) | `verboseCheck` |
| [08](./examples/Example08.hs) | `quickCheckWith` と `Args` |
| [09](./examples/Example09.hs) | `counterexample` |
| [10](./examples/Example10.hs) | `(.&&.)` `conjoin` など |

### 第2章 プロパティの見つけ方

| # | 内容 |
|---|---|
| [11](./examples/Example11.hs) | 往復（`show`/`read`、Double の NaN） |
| [12](./examples/Example12.hs) | 往復でバグを見つける（ランレングス符号化） |
| [13](./examples/Example13.hs) | 不変条件（1つでは足りない） |
| [14](./examples/Example14.hs) | 冪等性 |
| [15](./examples/Example15.hs) | 代数法則（自作 Monoid） |
| [16](./examples/Example16.hs) | テストオラクル |
| [17](./examples/Example17.hs) | メタモルフィック関係 |
| [18](./examples/Example18.hs) | 構造に沿った性質 |
| [19](./examples/Example19.hs) | 全域性（`total`） |
| [20](./examples/Example20.hs) | 同じ計算の2つの書き方 |
| [21](./examples/Example21.hs) | ケーススタディ：連想リスト（13本） |
| [22](./examples/Example22.hs) | ケーススタディ：property-first |

### 第3章 ジェネレータ入門

| # | 内容 |
|---|---|
| [23](./examples/Example23.hs) | `Arbitrary` / `sample` |
| [24](./examples/Example24.hs) | `choose` / `elements` / `forAll` |
| [25](./examples/Example25.hs) | `oneof` / `frequency` |
| [26](./examples/Example26.hs) | リストの生成 |
| [27](./examples/Example27.hs) | `suchThat` の危険 |
| [28](./examples/Example28.hs) | Functor / Applicative / Monad |
| [29](./examples/Example29.hs) | `sized` / `resize` / `scale` |
| [30](./examples/Example30.hs) | 生成器そのものをテストする |

### 第4章 自作型の生成器

| # | 内容 |
|---|---|
| [31](./examples/Example31.hs) | 自作型に `Arbitrary` |
| [32](./examples/Example32.hs) | レコード型と列挙型 |
| [33](./examples/Example33.hs) | 再帰型は素朴に書くと壊れる |
| [34](./examples/Example34.hs) | `sized` の書き方 |
| [35](./examples/Example35.hs) | 不変条件を持つ型 |
| [36](./examples/Example36.hs) | `newtype` で戦略を切り替える |
| [37](./examples/Example37.hs) | 実例：JSON の往復テスト |
| [38](./examples/Example38.hs) | 実例：日付（うるう年・月末） |
| [39](./examples/Example39.hs) | 生成器の部品化 |
| [40](./examples/Example40.hs) | 無効な入力も生成する |
| [41](./examples/Example41.hs) | 関数の生成（`Fun`） |
| [42](./examples/Example42.hs) | `CoArbitrary` と `Function` |
| [43](./examples/Example43.hs) | 型クラス則の検査 |
| [44](./examples/Example44.hs) | `forAll` 系の使い分け |
| [45](./examples/Example45.hs) | `Arbitrary` か `forAll` か |
| [46](./examples/Example46.hs) | 総合演習：在庫管理 |

### 第5章 縮小 shrinking

| # | 内容 |
|---|---|
| [47](./examples/Example47.hs) | shrink がないとどうなるか |
| [48](./examples/Example48.hs) | 契約とデフォルト実装 |
| [49](./examples/Example49.hs) | 自作型に shrink を書く |
| [50](./examples/Example50.hs) | `shrinkList` / `shrinkMap` など |
| [51](./examples/Example51.hs) | `genericShrink` |
| [52](./examples/Example52.hs) | 事故1：不変条件を壊す |
| [53](./examples/Example53.hs) | 事故2：終わらない |
| [54](./examples/Example54.hs) | 再帰型の shrink |
| [55](./examples/Example55.hs) | 探索順序と局所最小 |
| [56](./examples/Example56.hs) | 縮小のデバッグ |
| [57](./examples/Example57.hs) | 縮小を制御する道具 |
| [58](./examples/Example58.hs) | 総合演習：ページング条件 |

### 第6章 前提条件と Modifier

| # | 内容 |
|---|---|
| [59](./examples/Example59.hs) | `(==>)` の基本 |
| [60](./examples/Example60.hs) | Gave up（確率の実測） |
| [61](./examples/Example61.hs) | 条件で絞ると分布が歪む |
| [62](./examples/Example62.hs) | 数値の Modifier |
| [63](./examples/Example63.hs) | リスト・文字列の Modifier |
| [64](./examples/Example64.hs) | `discard` |
| [65](./examples/Example65.hs) | 自作 Modifier |
| [66](./examples/Example66.hs) | プロパティ全体の修飾 |
| [67](./examples/Example67.hs) | リファクタ実例（discarded 1000 → 0） |
| [68](./examples/Example68.hs) | 条件が複数あるとき |
| [69](./examples/Example69.hs) | `(==>)` を使ってよい場面 |
| [70](./examples/Example70.hs) | 総合演習：予約システム |

### 第7章 分布とカバレッジ

| # | 内容 |
|---|---|
| [71](./examples/Example71.hs) | `collect` |
| [72](./examples/Example72.hs) | `label` と `classify` |
| [73](./examples/Example73.hs) | `tabulate` |
| [74](./examples/Example74.hs) | `cover` |
| [75](./examples/Example75.hs) | `checkCoverage` |
| [76](./examples/Example76.hs) | `coverTable` |
| [77](./examples/Example77.hs) | **事故の完全な実演** |
| [78](./examples/Example78.hs) | 分布を直す技法カタログ（7種） |
| [79](./examples/Example79.hs) | 測定ヘルパーと生成器ガード |
| [80](./examples/Example80.hs) | 総合演習：API ハンドラ |

### 第8章 実践

| # | 内容 |
|---|---|
| [81](./examples/Example81.hs) | `ioProperty` |
| [82](./examples/Example82.hs) | `monadicIO` |
| [83](./examples/Example83.hs) | 例外のテスト（遅延評価の罠） |
| [84](./examples/Example84.hs) | `within`（タイムアウト） |
| [85](./examples/Example85.hs) | `replay` とシード |
| [86](./examples/Example86.hs) | `Result` を扱う |
| [87](./examples/Example87.hs) | モデルベーステスト入門 |
| [88](./examples/Example88.hs) | **state machine テスト** |
| [89](./examples/Example89.hs) | 並行処理の競合検出 |
| [90](./examples/Example90.hs) | パーサ／pretty printer の往復 |
| [91](./examples/Example91.hs) | 二分探索木を丸ごと検証（23本） |
| [92](./examples/Example92.hs) | 総合演習：LRU キャッシュ |

### 第9章 プロジェクトでの運用

| # | 内容 |
|---|---|
| [93](./examples/Example93.hs) | プロジェクト構成とテストランナー |
| [94](./examples/Example94.hs) | 実行プロファイルとシード |
| [95](./examples/Example95.hs) | 回帰テスト |
| [96](./examples/Example96.hs) | CI での運用 |
| [97](./examples/Example97.hs) | 既存プロジェクトへの導入 |
| [98](./examples/Example98.hs) | アンチパターン集 |
| [99](./examples/Example99.hs) | 変異テストでプロパティを育てる |
| [100](./examples/Example100.hs) | **総仕上げ**：価格計算エンジン |

## 🧰 全 Example をまとめて実行

```bash
./run-all.sh            # 100 件すべて
./run-all.sh 01 05 12   # 番号を指定
```

見ているのは「Haskell として動くか（終了コード 0）」です。
教材には**わざと失敗するプロパティ**が多数含まれています。

## 🏗 第9章のプロジェクト

```bash
cd project
cabal test --test-show-details=direct
```

ライブラリ3モジュール + プロパティ 42 本（state machine テスト・回帰テスト込み）が動きます。

## ⚠️ 補足

- **プログラムの出力は ASCII です。** `LANG` 未設定の環境で日本語が化けるのを避けるため、
  日本語の解説はすべてソースコードのコメントと `docs/` にあります。
- 動作確認は GHC 9.4.7 / QuickCheck 2.14.3 で行いました。
  `Test.QuickCheck` のエクスポートのみを使い、内部モジュールには
  `Test.QuickCheck.Gen (unGen)` と `Test.QuickCheck.Random (mkQCGen)` 以外依存していません。
