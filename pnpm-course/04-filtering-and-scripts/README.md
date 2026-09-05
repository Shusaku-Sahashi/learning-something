# 04. フィルタリングとスクリプト実行

## この章のゴール

- `pnpm -r`（recursive）で全ワークスペースにコマンドを実行できる
- `--filter` の各種パターン（単一パッケージ、依存を含める、依存元を含める）を使い分けられる
- `--parallel` の効果と、依存関係トポロジカル順序の関係を理解する

## プロジェクト構成

`project/` には依存関係を持つ3つのパッケージがあります。

```
@sample/app  ──depends on──> @sample/ui ──depends on──> @sample/core
      │                                                       ▲
      └───────────────────depends on─────────────────────────┘
```

それぞれの `build` スクリプトは、実際のビルドの代わりに `sleep 0.5` してメッセージを表示するだけの
ダミーです（実行順序と所要時間を観察しやすくするため）。

```bash
cd pnpm-course/04-filtering-and-scripts/project
pnpm install
```

## ハンズオン

### 1. 全パッケージでスクリプトを実行する（`-r` / `--recursive`）

```bash
pnpm -r run build
```

`core → ui → app` の順で実行されるはずです。これは pnpm がワークスペースの依存関係グラフを解析し、
**依存されている側から先に実行する（トポロジカルソート）** ためです。`app` は `ui` と `core` に依存しているので、
`app` のビルドより先に両者が終わっている必要がある、という考え方です。

### 2. 特定のパッケージだけに絞る（`--filter`）

```bash
pnpm --filter @sample/ui run build
```

`ui` だけが実行されます。依存元・依存先は一切実行されません。

### 3. 依存関係を含めて実行する（`...` サフィックス）

「このパッケージをビルドするために必要なもの全部」を実行したい場合は、パッケージ名の後ろに `...` を付けます。

```bash
pnpm --filter "@sample/app..." run build
```

`app` が依存している `ui` と `core` も含めて、正しい順序（`core → ui → app`）で実行されます。

### 4. 依存元を含めて実行する（`...` プレフィックス）

逆に「このパッケージを変更したときに影響を受けるパッケージも含めて」実行したい場合は、パッケージ名の前に `...` を付けます。

```bash
pnpm --filter "...@sample/core" run build
```

`core` に依存している `ui` と `app` も含めて実行されます（`core` に変更を入れたときの影響確認や CI でよく使うパターンです）。

### 5. ディレクトリで指定する

パッケージ名の代わりにパスでも指定できます。

```bash
pnpm --filter "./packages/ui" run build
```

### 6. 並列実行する（`--parallel`）

デフォルトの `-r` は依存関係の順序を守って**直列**に実行しますが、`--parallel` を付けると
依存関係の順序を無視してすべて同時に実行します。

```bash
time pnpm -r run build
echo "---"
time pnpm --parallel -r run build
```

3パッケージとも `sleep 0.5` しているので、直列実行は合計で 1.5 秒前後、並列実行は 0.5 秒強で終わるはずです。
実行結果のログの `[core] building...` `[ui] building...` `[app] building...` の出力タイミングが
インターリーブ（入り乱れる）していることも確認してみましょう。

> `--parallel` は「依存関係を無視して良い」シチュエーション（例えば複数の開発サーバーを同時に立ち上げる `dev` スクリプトなど）で使うものです。ビルド成果物に依存関係があるような `build` では、順序を保証する通常の `-r` の方が安全な場合が多いです。

## `--filter` チートシート

| 書き方 | 意味 |
|---|---|
| `--filter foo` | `foo` パッケージのみ |
| `--filter foo...` | `foo` とその依存（dependencies）全部 |
| `--filter ...foo` | `foo` とそれに依存している（dependents）パッケージ全部 |
| `--filter ./packages/foo` | パス指定 |
| `--filter "./packages/**"` | glob パターンでの指定 |
| `-r` / `--recursive` | 全ワークスペースパッケージが対象（順序は依存関係に従う） |

## 確認ポイント

- [ ] `pnpm -r run build` の実行順序が依存関係に従っている
- [ ] `--filter foo...` と `--filter ...foo` の違いを説明できる
- [ ] `--parallel` を付けると依存順序を無視して同時実行されることを確認した

## 深掘り課題

- `packages/app/package.json` に `"scripts": { "dev": "echo '[app] watching...' && sleep 5 }"` のような長時間実行スクリプトを追加し、`--parallel` で3パッケージ同時に `dev` を起動する体験をしてみましょう（`Ctrl+C` で止められます）。
- `pnpm --filter "@sample/app..." --filter "!@sample/app" run build`（自分自身を除外するパターン）のように、複数の `--filter` を組み合わせるとどうなるか試してみましょう。

---

前: [03. workspace でモノレポを作る](../03-workspace-monorepo/README.md) ｜ 次: [05. 依存関係の管理](../05-dependency-management/README.md)
