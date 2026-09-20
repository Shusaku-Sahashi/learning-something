# quickcheck-bootcamp (Ch9 の題材プロジェクト)

Ch9 で扱う「QuickCheck を実プロジェクトに組み込む」ための、動く最小構成です。

## 構成

```
project/
├── quickcheck-bootcamp.cabal   パッケージ定義 (library + test-suite)
├── cabal.project
├── src/Bootcamp/
│   ├── Queue.hs                2リスト実装のキュー (表現不変条件つき)
│   ├── Text.hs                 chunksOf / splitOn / ellipsis など
│   └── Interval.hs             閉区間 (lo <= hi が不変条件)
├── test/
│   ├── Spec.hs                 エントリポイント。環境変数でプロファイルを切り替える
│   ├── Runner.hs               小さなテストランナー (QuickCheck だけで完結)
│   ├── Gen/                    生成器。テスト全体で使い回す
│   │   ├── Queue.hs
│   │   └── Interval.hs
│   └── Props/                  プロパティ本体
│       ├── Queue.hs            state machine テストを含む
│       ├── Text.hs
│       ├── Interval.hs
│       └── Regression.hs       過去の反例を固定したテスト
└── .github/workflows/ci.yml    CI の例
```

## 実行

```bash
cabal test                                  # dev プロファイル (maxSuccess = 100)
cabal test --test-show-details=direct       # 出力をそのまま見る (おすすめ)

QC_PROFILE=ci      cabal test --test-show-details=direct   # maxSuccess = 1000
QC_PROFILE=nightly cabal test --test-show-details=direct   # maxSuccess = 50000

QC_SEED=12345 cabal test --test-show-details=direct        # シードを固定して再現
```

## この構成のポイント

1. **生成器を `test/Gen/` に分離する**
   複数のプロパティモジュールから使い回せます。
   生成器そのもののプロパティも、ここに近い場所に置けます。

2. **プロパティを対象モジュールごとに分ける**
   `Props.Queue` は `Bootcamp.Queue` に対応します。
   モジュールが増えてもファイルが肥大化しません。

3. **`Props/Regression.hs` を必ず作る**
   QuickCheck が見つけた反例は、`once` を使った固定テストとして残します。
   ランダムテストは「同じ反例をもう一度引く」保証がないからです。

4. **プロファイルを環境変数で切り替える**
   開発中は速く、CI では多めに、夜間はたっぷり。
   `Runner.hs` の `devArgs` / `ciArgs` / `nightlyArgs` で数値を一元管理します。

5. **シードを固定できるようにしておく**
   `QC_SEED` で `replay` を設定できます。
   CI が落ちたとき、同じ入力列を手元で再現できます。

6. **追加の依存を持たない**
   `base` と `QuickCheck` だけで動きます。
   tasty や hspec を使う場合は `Runner.hs` を捨てて、それぞれの流儀に従ってください。

## tasty / hspec を使う場合

このプロジェクトは追加依存なしで動かすため、自前の `Runner.hs` を使っています。
実務では次のどちらかを使うことが多いです。

```haskell
-- tasty + tasty-quickcheck
import Test.Tasty
import Test.Tasty.QuickCheck

main :: IO ()
main = defaultMain (testGroup "all"
  [ testProperty "fifo order" prop_fifo
  , ...
  ])
-- 実行: cabal test --test-options='--quickcheck-tests=1000'
-- 失敗時に --quickcheck-replay=... が表示され、そのまま再現できます
```

```haskell
-- hspec + QuickCheck
import Test.Hspec
import Test.Hspec.QuickCheck (prop)

main :: IO ()
main = hspec $ describe "Queue" $ do
  prop "fifo order" prop_fifo
```

どちらも `build-depends` に追加するだけで使えます。
`--quickcheck-replay` が使える分、実務では tasty のほうが便利な場面が多いです。
