# 01. はじめての pnpm

## この章のゴール

- `pnpm init` でプロジェクトを作成できる
- `pnpm add` / `pnpm add -D` で依存関係を追加できる
- `pnpm remove` で依存関係を削除できる
- `pnpm run` でスクリプトを実行できる
- `package.json` と `pnpm-lock.yaml` の役割を理解する

## ハンズオン

`project/` ディレクトリは空です。ここに 1 からプロジェクトを作っていきます。

### 1. プロジェクトを初期化する

```bash
cd pnpm-course/01-getting-started/project
pnpm init
```

`package.json` が生成されます。npm の `npm init -y` と同等の内容に加えて、
`packageManager` フィールドが自動で追加されているのを確認してください（これは Corepack がこのプロジェクトで使う pnpm のバージョンを固定するためのフィールドです）。

```json
{
  "name": "project",
  "version": "1.0.0",
  ...
  "packageManager": "pnpm@10.33.0"
}
```

### 2. 依存関係を追加する

日付操作ライブラリ [dayjs](https://day.js.org/) を通常の依存関係として追加します。

```bash
pnpm add dayjs
```

続けて、開発時だけ使うツール（フォーマッタ）を devDependencies として追加します。

```bash
pnpm add -D prettier
```

`package.json` を開いて、`dependencies` と `devDependencies` にそれぞれ追加されたことを確認しましょう。

```json
"dependencies": {
  "dayjs": "^1.11.21"
},
"devDependencies": {
  "prettier": "^3.9.6"
}
```

同時に `pnpm-lock.yaml` というファイルが生成されています。これは「実際にインストールされた正確なバージョンと依存ツリー」を記録するファイルで、
チーム全員・CI で全く同じ `node_modules` を再現するために使われます（`package.json` の `^1.11.21` のような範囲指定だけでは、
人によって微妙に違うバージョンが入ってしまう可能性があるため）。

> `pnpm-lock.yaml` はこのコースでは `.gitignore` していますが、実際のプロジェクトでは **必ず Git にコミットします**。

### 3. コードを書いて実行する

`index.js` を作成します。

```js
// index.js
import dayjs from "dayjs";

const now = dayjs();
console.log(`今日の日付: ${now.format("YYYY-MM-DD")}`);
```

`package.json` の `type` を `module` にして ESM を有効にし、`scripts` に `start` を追加します。

```json
{
  "type": "module",
  "scripts": {
    "start": "node index.js"
  }
}
```

実行します。

```bash
pnpm run start
# もしくは短縮形
pnpm start
```

`今日の日付: 2026-08-04` のような出力が出れば成功です。

### 4. フォーマッタを実行する

devDependencies に入れた `prettier` は `node_modules/.bin/prettier` に実行ファイルとして配置されています。
`pnpm exec` を使うと、そのプロジェクトの `node_modules/.bin` にあるコマンドをパスを気にせず実行できます。

```bash
pnpm exec prettier --check index.js
```

### 5. 依存関係を削除する

```bash
pnpm remove prettier
```

`package.json` の `devDependencies` から `prettier` が消え、`node_modules/prettier` の symlink も削除されることを確認してください。

## 確認ポイント

- [ ] `package.json` に `dayjs` が `dependencies` として記録されている
- [ ] `pnpm-lock.yaml` が生成されている
- [ ] `pnpm start` で日付が出力される
- [ ] `pnpm remove` 後、`package.json` と `node_modules` の両方から該当パッケージが消えている

## npm との対応表

| npm | pnpm |
|---|---|
| `npm install` | `pnpm install`（`pnpm i`） |
| `npm install express` | `pnpm add express` |
| `npm install -D typescript` | `pnpm add -D typescript` |
| `npm install -g pnpm` | `pnpm add -g pnpm` |
| `npm uninstall express` | `pnpm remove express` |
| `npm run build` | `pnpm run build`（`pnpm build`） |
| `npx <cmd>` | `pnpm dlx <cmd>`（[Module 07](../07-dlx-npmrc-ci/README.md) で解説） |

## 深掘り課題

- `pnpm add express@4` のようにバージョンを指定して追加してみましょう。
- `pnpm add -D` で追加したパッケージと、通常の `pnpm add` で追加したパッケージで、`pnpm install --prod` を実行したときの挙動の違いを確認してみましょう（`devDependencies` はインストールされません）。

---

前: [00. pnpm とは何か](../00-introduction/README.md) ｜ 次: [02. node_modules の構造とストア](../02-node-modules-and-store/README.md)
