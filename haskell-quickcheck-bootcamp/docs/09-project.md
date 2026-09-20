# 🚀 第9章 プロジェクトでの運用（Example 93–100）

## この章のゴール

学んだことを実プロジェクトに載せ、**壊れないように維持する**仕組みを作ります。

実際に動くプロジェクトが [`../project/`](../project/) にあります。
まずこれを動かしてください。

```bash
cd ../project
cabal test --test-show-details=direct
```

## ディレクトリ構成

```
myproject/
├── myproject.cabal
├── src/
│   └── MyLib/
│       ├── Queue.hs
│       └── Text.hs
└── test/
    ├── Spec.hs            エントリポイント
    ├── Runner.hs          テストランナー（または tasty/hspec）
    ├── Gen/               生成器。複数のプロパティから使い回す
    │   └── Queue.hs
    └── Props/             プロパティ本体。src のモジュールに対応させる
        ├── Queue.hs
        ├── Text.hs
        └── Regression.hs  過去の反例を固定したテスト
```

cabal の設定：

```cabal
test-suite spec
    type:             exitcode-stdio-1.0
    main-is:          Spec.hs
    other-modules:    Gen.Queue, Props.Queue, Props.Text, Props.Regression, Runner
    hs-source-dirs:   test
    build-depends:    base, QuickCheck, myproject
    default-language: Haskell2010
```

`exitcode-stdio-1.0` は「実行ファイルを走らせ、終了コード 0 なら成功」という方式です。
QuickCheck だけで完結でき、追加のテストフレームワークが要りません。

⚠️ `cabal test` は既定では出力を隠します。**`--test-show-details=direct` を付けてください。**

## 実行プロファイル

数値を1箇所にまとめ、環境変数で切り替えます。

```haskell
devArgs     = stdArgs { maxSuccess = 100,   maxSize = 100 }
ciArgs      = stdArgs { maxSuccess = 1000,  maxSize = 100 }
nightlyArgs = stdArgs { maxSuccess = 50000, maxSize = 300 }
```

```bash
cabal test                                   # dev
QC_PROFILE=ci      cabal test                # PR ごと
QC_PROFILE=nightly cabal test                # 夜間バッチ
QC_SEED=12345      cabal test                # 再現
```

個別の上書きは `withMaxSuccess` で。プロパティの定義のすぐそばに書けます。

## 回帰テスト

**バグを直したら、必ず回帰テストを1本足してください。**

ランダムテストは「同じ反例をもう一度引く」保証がありません。
シードを固定しても、生成器を変えると別の入力になります。

```haskell
-- #3 2026-09-20: prop_ellipsisBounded が (n=3, "abcdef") で落ちた。
--   n <= 3 のとき take (n-3) s ++ "..." が長さ 3 を超えていた。
regr_ellipsisSmallN :: Property
regr_ellipsisSmallN = once $
  conjoin
    [ counterexample "n = 0" (ellipsis 0 "abcdef" === "")
    , counterexample "n = 3" (ellipsis 3 "abcdef" === "abc")
    , counterexample "n = 4" (ellipsis 4 "abcdef" === "a...")
    ]
```

運用ルール：

1. バグを直したら、必ず回帰テストを足す
2. 反例そのものではなく**「反例の周辺」も**入れる（`n = 3` で落ちたなら 0,1,2,3,4 全部）
3. コメントに「いつ・なぜ」を残す
4. `once` を使う（付けないと同じテストを 100 回繰り返す）
5. 専用のモジュール（`Props/Regression.hs`）にまとめる

## CI

```yaml
on:
  push: { branches: [main] }
  pull_request:
  schedule:
    - cron: '0 18 * * *'

jobs:
  test:
    strategy:
      matrix:
        ghc: ['9.4.8', '9.6.4']
    steps:
      - uses: actions/checkout@v4
      - uses: haskell-actions/setup@v2
        with: { ghc-version: '${{ matrix.ghc }}' }
      - uses: actions/cache@v4
        with:
          path: ~/.cabal/store
          key: ${{ runner.os }}-ghc${{ matrix.ghc }}-${{ hashFiles('**/*.cabal') }}
      - run: cabal update
      - name: tests
        if: github.event_name != 'schedule'
        env: { QC_PROFILE: ci }
        run: cabal test --test-show-details=direct
      - name: nightly
        if: github.event_name == 'schedule'
        env: { QC_PROFILE: nightly }
        run: cabal test --test-show-details=direct
```

チェックリスト：
- [ ] `--test-show-details=direct` を付ける
- [ ] シードをログに出す
- [ ] PR と夜間でプロファイルを分ける
- [ ] cabal store をキャッシュする
- [ ] 複数の GHC バージョンで回す
- [ ] `cover` / `checkCoverage` を CI で回して、生成器の劣化を検出する
- [ ] 捨てる割合が多いプロパティを可視化する

## 既存プロジェクトへの導入（Example 97）

1. **既存の単体テストは消さない。** `once` でプロパティの形に包むだけ
2. 1つの単体テストにつき、1つ「一般化した性質」を書く
   （「この例が通るべき**理由**は何か？」を言葉にすると、それが性質です）
3. 第2章のパターン集を順に当てはめる
4. 生成器を現実の入力に近づける。`classify` で分布を確認する
5. バグが見つかったら、直して回帰テストを足す

どこから始めるか：
- **純粋関数から。** IO が絡むところは後回し
- **「変換」系の関数が狙い目。** 往復や冪等性がすぐ書ける
- **バグがよく出るモジュールから。** 効果が目に見える

やってはいけないこと：
- 既存の単体テストを消してプロパティに置き換える（単体テストは「この具体例は絶対に守る」という宣言。両方あってよい）
- 最初から全モジュールに入れようとする（1つで成功体験を作ってから広げる）

## アンチパターン集（Example 98）

| # | アンチパターン | なぜダメか |
|---|---|---|
| 1 | 実装をそのまま書き写す | バグがあれば両方に同じバグが入る |
| 2 | トートロジー（`length xs >= 0`） | どんな実装でも成り立つ |
| 3 | 条件が厳しすぎる | 実質数件しか実行されない |
| 4 | 生成器が偏っている | 分岐に届かない |
| 5 | shrink を書かない | 反例が読めない |
| 6 | 失敗しても情報がない | 原因が分からない |

自己点検：
- [ ] テスト対象を `undefined` に置き換えたら、このプロパティは落ちるか？
- [ ] 実装をわざと壊したら、このプロパティは落ちるか？
- [ ] `discarded` の数はゼロに近いか？
- [ ] `classify` で見て、狙った分岐に届いているか？
- [ ] 反例は読める大きさまで縮んでいるか？
- [ ] 反例を見て、原因の見当がつくか？

## 変異テストでプロパティを育てる（Example 99）

テスト対象をわざと壊した版（ミュータント）を用意し、
「プロパティがそれを全部殺せるか」を見ます。

挿入ソートの実測結果：

| プロパティ集合 | スコア |
|---|---|
| V1: `ordered` だけ | 4/8 (50%) |
| V2: + 長さ保存 | 7/8 (87%) |
| V3: + 同じ多重集合 | 7/8 (87%) |
| V4: + 冪等性、先頭が最小 | 7/8 (87%) |

殺せなかった M7（`<=` を `<` に変えたもの）は**等価ミュータント**です。
要素が `Int` だと等しい値を区別できないため、出力が完全に一致します。
どんなプロパティでも殺せません。

ただし、キー付きの要素をキーだけで並べる場面では、**安定性の差**として現れます。
「今の型では区別できないが、使い方次第では意味がある差」なのです。

殺せないミュータントが残ったら、次のどちらかです：
- **(a) 仕様の穴**：プロパティが足りない → 足す
- **(b) 等価ミュータント**：振る舞いが同じ → 殺せない（元の実装と出力が常に一致するか確かめて判定）

### 「完全な仕様」に到達したかの見分け方

ソートの場合、「順序が正しい」かつ「元と同じ多重集合」を両方満たす実装は、ソートしかありえません。
つまり V3 で仕様は完全です。

自分の関数についても
**「この性質を全部満たす、間違った実装を書けるか？」**
と自問してください。書けなくなったら、そこがゴールです。

## Example 一覧

| # | 内容 |
|---|---|
| [93](../examples/Example93.hs) | プロジェクト構成。最小のテストランナー |
| [94](../examples/Example94.hs) | 実行プロファイルとシードの管理 |
| [95](../examples/Example95.hs) | 回帰テストを作る |
| [96](../examples/Example96.hs) | CI で運用する |
| [97](../examples/Example97.hs) | 既存プロジェクトに導入する |
| [98](../examples/Example98.hs) | アンチパターン集 |
| [99](../examples/Example99.hs) | 変異テストでプロパティを育てる |
| [100](../examples/Example100.hs) | **総仕上げ**：価格計算エンジンを全部の技で固める |

## さらに先へ

| ライブラリ | 何をするもの |
|---|---|
| `quickcheck-state-machine` / `quickcheck-dynamic` | Example 88 の骨組みを汎用化。並行テストもできる |
| `hedgehog` | 生成器と縮小が一体になった設計。`shrink` を書く必要がない |
| `tasty-quickcheck` / `hspec` | テストフレームワークとの統合。`--quickcheck-replay` が便利 |
| `validity` / `genvalidity` | 「型の妥当性」を中心に据えたアプローチ |
| `MuCheck` | 変異テストの自動化 |
| `dejafu` | 並行プログラムのスケジュールを網羅的に探索 |

## 完走おめでとうございます 🎉

→ [API 早見表](./99-cheatsheet.md)
