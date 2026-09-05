# 06. パッチとカタログ

pnpm の中でも特に強力な、他のパッケージマネージャーにはあまりない2つの機能を扱います。

- **`pnpm patch`**: node_modules 内のパッケージのソースコードを直接書き換えて、その差分を Git 管理できる形で保存する
- **catalog（カタログ）**: モノレポ内の複数パッケージで使うバージョンを1箇所で一元管理する

## この章のゴール

- 公開されているパッケージにバグを見つけたとき、`pnpm patch` でその場しのぎの修正を当てられる
- パッチが `pnpm-lock.yaml` / `pnpm-workspace.yaml` にどう記録されるか理解する
- `catalog:` プロトコルで、モノレポ内のバージョンのばらつきを防げる

---

## Part A: pnpm patch

### 前提

`project-patch/` には `is-positive`（数値が正かどうかを判定するだけの小さなパッケージ）に依存するプロジェクトがあります。

```bash
cd pnpm-course/06-patch-and-catalog/project-patch
pnpm install
```

### 1. パッチ対象パッケージを開く

```bash
pnpm patch is-positive@3.1.0
```

「ここを編集してください」という一時ディレクトリのパスが表示されます（例: `node_modules/.pnpm_patches/is-positive@3.1.0`）。
このパスは実行ごとに変わるので、表示された実際のパスを使ってください。

### 2. ソースコードを直接編集する

表示されたディレクトリの `index.js` を開くと、次のような中身になっています。

```js
'use strict';
module.exports = function (n) {
	return toString.call(n) === '[object Number]' && n > 0;
};
```

ここに、呼び出しをログ出力する1行を足してみましょう。

```js
'use strict';
module.exports = function (n) {
	console.log('[patched] is-positive called with', n);
	return toString.call(n) === '[object Number]' && n > 0;
};
```

### 3. パッチを確定する

手順1で表示されたパス（コマンドの出力にある `pnpm patch-commit '...'` をそのままコピーするのが確実です）を使って確定します。

```bash
pnpm patch-commit 'node_modules/.pnpm_patches/is-positive@3.1.0'
```

### 4. 何が起きたか確認する

```bash
cat pnpm-workspace.yaml
```

```yaml
patchedDependencies:
  is-positive@3.1.0: patches/is-positive@3.1.0.patch
```

`patches/is-positive@3.1.0.patch` という差分ファイル（git diff 形式）が生成され、
`pnpm-workspace.yaml` にそのパッケージ・バージョンへのパッチとして登録されました。

```bash
cat patches/is-positive@3.1.0.patch
```

```diff
--- a/index.js
+++ b/index.js
@@ -1,4 +1,5 @@
 'use strict';
 module.exports = function (n) {
+	console.log('[patched] is-positive called with', n);
 	return toString.call(n) === '[object Number]' && n > 0;
 };
```

この `.patch` ファイルは通常のテキストファイルなので、**Git にコミットして他のメンバーとも共有できます**。
他の人が `pnpm install` するだけで、同じパッチが自動的に適用された状態の `node_modules` が再現されます。

### 5. パッチが効いていることを確認する

```bash
node -e "const isPositive = require('is-positive'); console.log('result:', isPositive(5));"
```

`[patched] is-positive called with 5` というログが、パッチしていない `is-positive` 本来の動作の前に出力されます。

> パッチは「本家に PR を送るまでの応急処置」として使うのが基本です。恒久対応ではなく、
> 一時しのぎであることをコード上（コミットメッセージや `patches/` 内のコメント）に残しておくと安全です。

## Part B: catalog（バージョンの一元管理）

### 前提

モノレポで複数のパッケージが同じ外部ライブラリ（例えば `dayjs` や `react`）を使う場合、
うっかりパッケージごとに異なるバージョンを指定してしまうことがあります。catalog はこれを防ぐための機能です。

`project-catalog/` の `pnpm-workspace.yaml` を見てみましょう。

```yaml
packages:
  - "packages/*"

catalog:
  dayjs: ^1.11.21

catalogs:
  react17:
    react: ^17.0.2
```

- `catalog:` （名前なし・デフォルトカタログ）には `dayjs` のバージョンが1つ定義されています。
- `catalogs.react17` という名前付きカタログには `react` のバージョンが定義されています。

`packages/pkg-a/package.json` と `packages/pkg-b/package.json` は、どちらも `dayjs` を次のように参照しています。

```json
"dependencies": {
  "dayjs": "catalog:"
}
```

### 1. インストールしてバージョンが揃うことを確認する

```bash
cd pnpm-course/06-patch-and-catalog/project-catalog
pnpm install
node -p "require('./packages/pkg-a/node_modules/dayjs/package.json').version"
node -p "require('./packages/pkg-b/node_modules/dayjs/package.json').version"
```

2つとも `pnpm-workspace.yaml` の `catalog.dayjs` に書いた **同じバージョン** になっているはずです。
`catalog:` を使わずに各パッケージで `"dayjs": "^1.11.21"` のように個別指定していると、
将来どちらかだけ更新し忘れてバージョンがズレる、という事故が起こり得ます。catalog はそれを構造的に防ぎます。

### 2. 名前付きカタログを使ってみる

`packages/pkg-b/package.json` に `react` を、名前付きカタログ `react17` を参照する形で追加してみましょう。

```json
{
  "name": "@sample/pkg-b",
  "version": "1.0.0",
  "dependencies": {
    "dayjs": "catalog:",
    "react": "catalog:react17"
  }
}
```

```bash
pnpm install
node -p "require('./packages/pkg-b/node_modules/react/package.json').version"
```

`pnpm-workspace.yaml` の `catalogs.react17.react` に書いた `17.0.2` がインストールされます。
名前付きカタログは「新しいパッケージは React 18 系、レガシーな一部のパッケージだけ React 17 系」のような、
バージョンを意図的に複数系統に分けたい場合に使います。

### 3. カタログのバージョンを一括更新する

`pnpm-workspace.yaml` の `catalog.dayjs` を `^1.11.10` のように変更して `pnpm install` を実行すると、
`dayjs` を `catalog:` で参照している全パッケージのバージョンが一括で追従します。
「1箇所直せば全パッケージに反映される」のが catalog の最大のメリットです。

## 確認ポイント

- [ ] `pnpm patch` → ソース編集 → `pnpm patch-commit` の一連の流れを実行できた
- [ ] `patches/*.patch` と `pnpm-workspace.yaml` の `patchedDependencies` の対応関係を説明できる
- [ ] `catalog:` と `catalog:<name>` の違いを説明できる
- [ ] catalog のバージョンを1箇所変更すると、参照している全パッケージに反映されることを確認した

## 深掘り課題

- パッチを削除したくなったらどうすればよいか調べてみましょう（`pnpm-workspace.yaml` から該当エントリを消し、`patches/` の該当ファイルを削除して `pnpm install` します）。
- 実際のオープンソースパッケージにバグを見つけた想定で、`pnpm patch` を使って修正し、`git diff` 相当の `.patch` ファイルをそのまま Issue や PR の説明に貼り付けられることを確認してみましょう。

---

前: [05. 依存関係の管理](../05-dependency-management/README.md) ｜ 次: [07. dlx・.npmrc・CI 活用](../07-dlx-npmrc-ci/README.md)
