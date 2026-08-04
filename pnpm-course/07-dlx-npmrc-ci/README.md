# 07. dlx・.npmrc・CI 活用

最後の章では、日常的な開発フローと CI（継続的インテグレーション）で役立つ機能をまとめて扱います。

## この章のゴール

- `pnpm dlx` と `pnpm exec` の使い分けができる
- `.npmrc` でプロジェクト固有のインストール挙動を設定できる
- `--frozen-lockfile` が CI でなぜ重要かを、実際にエラーを起こして体験する

## ハンズオン

```bash
cd pnpm-course/07-dlx-npmrc-ci/project
pnpm install
```

### 1. `pnpm dlx`: インストールせずに一度だけ実行する

`dlx` は "download and execute" の略で、npm の `npx` に相当します。パッケージを `node_modules` や
`package.json` に一切残さず、一時的にダウンロードして実行するためのコマンドです。

```bash
pnpm dlx cowsay "hello pnpm"
```

実行後、`ls` してもこのディレクトリには何も追加されていないことを確認してください。
CLI ツールを一度だけ試したいときや、スキャフォールディングツール（`create-*` 系パッケージ）を実行するときに使います。

```bash
pnpm dlx create-vite my-app
```

### 2. `pnpm exec`: プロジェクトにインストール済みのコマンドを実行する

`dlx` と違い、`exec` は「すでにプロジェクトにインストールされている」パッケージの実行ファイルを、
パスを気にせず実行するためのコマンドです。

```bash
pnpm add -D cowsay
pnpm exec cowsay "installed locally"
```

`node_modules/.bin/cowsay` を直接呼び出すのと同じ結果になりますが、`pnpm exec` の方が短く、
モノレポでは `--filter` と組み合わせて特定パッケージ内の実行ファイルを呼べる利点もあります。

| コマンド | 対象 | 用途 |
|---|---|---|
| `pnpm dlx <pkg>` | レジストリから一時取得 | 一度きりの実行、スキャフォールディング |
| `pnpm exec <cmd>` | プロジェクトにインストール済みのもの | `package.json` に依存として書いてあるツールの実行 |

後片付けをしておきましょう。

```bash
pnpm remove cowsay
```

### 3. `.npmrc` でインストール挙動を変える

pnpm は `.npmrc` ファイル（プロジェクトルート、または `~/.npmrc` でユーザー全体）で多くの挙動をカスタマイズできます。
試しに `save-exact` を有効にしてみましょう。`project/.npmrc` を作成します。

```ini
save-exact=true
```

```bash
pnpm add is-positive
cat package.json
```

通常なら `"is-positive": "^3.1.0"` のように `^` 付きの範囲指定で保存されますが、
`save-exact=true` があると `"is-positive": "3.1.0"` のように厳密なバージョンで保存されます。
社内ライブラリなど、意図しない自動アップデートを避けたいプロジェクトでよく使われる設定です。

```bash
pnpm remove is-positive
```

よく使われるその他の `.npmrc` 設定も紹介します（このハンズオンでは設定するだけで、動作確認は任意です）。

| 設定 | 説明 |
|---|---|
| `auto-install-peers=true` | peer dependencies を自動インストールする（デフォルトで true。[Module 05](../05-dependency-management/README.md) 参照） |
| `shamefully-hoist=true` | npm 互換のフラットな `node_modules` に近づける（strict node_modules の恩恵が失われるため基本非推奨） |
| `engine-strict=true` | `package.json` の `engines` フィールドに合わないバージョンの Node.js だとインストールを失敗させる |
| `prefer-frozen-lockfile=true` | ロックファイルがあれば依存解決を省略し、そのまま使う（デフォルトで true。インストールを高速化） |

### 4. `--frozen-lockfile` を CI で使う理由を体験する

CI 環境では、「開発者がローカルで `pnpm-lock.yaml` の更新をコミットし忘れていないか」を検知する必要があります。
これを実現するのが `--frozen-lockfile` です（**pnpm は CI 環境を自動検出した場合、デフォルトでこのモードになります**）。

まず、ロックファイルと `package.json` が一致した状態で実行してみます。

```bash
pnpm install --frozen-lockfile
```

`Lockfile is up to date` と表示され、正常に終わります。

次に、`pnpm add` を使わずに **手で直接** `package.json` に依存を追記して、ロックファイルとの不整合を作ってみます。

```bash
node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json'));
pkg.dependencies['is-positive'] = '3.1.0';
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
"
pnpm install --frozen-lockfile
```

`ERR_PNPM_OUTDATED_LOCKFILE` というエラーで**インストール自体が失敗**するはずです。
これはまさに「`package.json` は変更したのに `pnpm-lock.yaml` の更新をコミットし忘れた PR」を CI が検知してくれる仕組みです。
`pnpm install`（`--frozen-lockfile` なし）ならロックファイルを自動更新して通ってしまいますが、
CI ではそれをせず、**開発者に手元でロックファイルを更新してコミットし直すことを強制する**のが正しい運用です。

後片付けとして、変更を元に戻しておきましょう。

```bash
git checkout -- package.json 2>/dev/null || true
pnpm install
```

## CI 設定例（GitHub Actions）

参考として、GitHub Actions で pnpm を使う典型的なワークフローを掲載します（実行はしません、参考資料です）。

```yaml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v4
        # package.json の packageManager フィールドからバージョンを自動検出

      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: "pnpm"

      - run: pnpm install --frozen-lockfile
      - run: pnpm run lint
      - run: pnpm run test
```

ポイントは次の3つです。

1. `pnpm/action-setup` で pnpm 自体をセットアップする（`package.json` の `packageManager` フィールドと連携）
2. `actions/setup-node` の `cache: "pnpm"` で pnpm store をキャッシュし、CI の実行時間を短縮する
3. `pnpm install --frozen-lockfile` を明示することで、ロックファイルの不整合を確実に検知する（前述の通り CI では自動で有効になりますが、明示しておくと意図が伝わりやすくなります）

## 確認ポイント

- [ ] `pnpm dlx` と `pnpm exec` の違いを説明できる
- [ ] `.npmrc` の `save-exact` の効果を確認した
- [ ] `--frozen-lockfile` が `package.json` とロックファイルの不整合を検知してインストールを失敗させることを確認した
- [ ] CI で `--frozen-lockfile` を使う意義を説明できる

## 深掘り課題

- `pnpm dlx` で `pnpm dlx npkill` のようなディスク掃除ツールを試してみましょう（実行するだけで `node_modules` を汚さないことを再確認できます）。
- 自分のマシンの `~/.npmrc`（ユーザーグローバル設定）と、プロジェクトの `.npmrc` の優先順位を公式ドキュメント https://pnpm.io/npmrc で確認してみましょう。

---

前: [06. パッチとカタログ](../06-patch-and-catalog/README.md)

## お疲れ様でした

これで pnpm ハンズオンコースは完了です。[コースの目次](../README.md#コースの構成) に戻って、
気になったモジュールを読み返したり、深掘り課題に挑戦してみてください。
