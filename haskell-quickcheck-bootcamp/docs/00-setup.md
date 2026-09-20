# 🛠 環境構築と進め方

## 必要なもの

- GHC 9.x
- QuickCheck 2.14 以上
- (Ch9 のみ) cabal 3.x

このコースは **base / containers / QuickCheck だけ**で完結します。
追加ライブラリは一切必要ありません。

## インストール

### ghcup を使う場合（推奨・どの OS でも）

```bash
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
ghcup install ghc 9.6.4
ghcup install cabal 3.10.3.0
ghcup set ghc 9.6.4

cabal update
cabal install --lib QuickCheck
```

### Debian / Ubuntu（apt）

```bash
sudo apt-get update
sudo apt-get install -y ghc libghc-quickcheck2-dev cabal-install
```

### macOS（Homebrew）

```bash
brew install ghcup
# 以降は ghcup の手順と同じ
```

### Nix

```bash
nix-shell -p 'haskellPackages.ghcWithPackages (p: [p.QuickCheck])'
```

## 動作確認

```bash
cd examples
runghc Example01.hs
```

次のように表示されれば成功です。

```
--- prop_reverseTwice ---
+++ OK, passed 100 tests.
--- prop_appendLength ---
+++ OK, passed 100 tests.
```

`Could not find module 'Test.QuickCheck'` と出る場合は、
QuickCheck がインストールされていないか、GHC から見えていません。
`ghc-pkg list | grep QuickCheck` で確認してください。

## 進め方

1. `docs/` の章を読む
2. その章の Example を**順番に実行する**
3. コード中のコメントを読む（解説の本体はコメントに書いてあります）
4. コードを書き換えて、予想と違う挙動を確かめる

**Example は必ず手を動かして実行してください。**
特に「わざと失敗させている」Example は、出力を見ないと意味がありません。

## 全部まとめて実行する

```bash
./run-all.sh          # 100 件すべて
./run-all.sh 01 05 12 # 番号を指定
```

`run-all.sh` が見ているのは「Haskell として動くか（終了コード 0）」です。
「全プロパティが成功するか」ではありません。
教材には**わざと失敗するプロパティ**が多数含まれています。

## 出力が日本語にならないことについて

Example のプログラムが画面に出す文字列は、すべて ASCII にしてあります。
これは `LANG` が未設定の環境で日本語が `?` に化けるのを避けるためです。
日本語の解説はすべて**ソースコードのコメント**と `docs/` にあります。

## この教材で使う QuickCheck のバージョン

動作確認は **GHC 9.4.7 / QuickCheck 2.14.3** で行っています。
2.14 系と 2.15 系では API はほぼ同じです。
`Test.QuickCheck` のエクスポートだけを使い、内部モジュールには
（`Test.QuickCheck.Gen` の `unGen` と `Test.QuickCheck.Random` の `mkQCGen` を除き）
依存していません。

## 次へ

→ [第1章 はじめてのプロパティ](./01-first-property.md)
