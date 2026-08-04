# 02. node_modules の構造とストア

## この章のゴール

- pnpm の `node_modules/.pnpm` 構造を実際に自分の目で見る
- 同じパッケージが複数プロジェクトで「実体を共有」していることをハードリンクで確認する
- Phantom Dependencies（幽霊依存）が pnpm では起きないことを体験する

## ハンズオン

### 1. プロジェクトを作って依存を1つ追加する

```bash
cd pnpm-course/02-node-modules-and-store/project
pnpm init
pnpm add express
```

`express` は内部で `body-parser` や `accepts` など多数のパッケージに依存しています。
npm や yarn (v1) ならこれらは全部 `node_modules` 直下にフラットに展開されますが、pnpm ではどうなるか見てみましょう。

```bash
ls node_modules
```

出力は `express` だけです（実際には `.bin` や `.modules.yaml`、`.pnpm` も見えます）。
`package.json` に書いていない `body-parser` は、直下からは見えません。

```bash
ls node_modules/.pnpm | grep body-parser
```

こちらには `body-parser@...` が存在します。「express が依存しているものはここにある」が、
「あなたのプロジェクトが直接使えるのはここだけ（node_modules 直下に symlink されたもの）」という2段構造になっています。

### 2. Phantom Dependency が起きないことを確認する

`package.json` に書いていない `body-parser` を、直接 import できてしまうかどうか試してみます。

```bash
cat > phantom-check.mjs << 'EOF'
try {
  await import("body-parser");
  console.log("import できてしまいました（Phantom Dependency！）");
} catch (e) {
  console.log("import 失敗（意図通り）:", e.code);
}
EOF
node phantom-check.mjs
```

`ERR_MODULE_NOT_FOUND` で失敗するはずです。npm のフラットな `node_modules` であれば、
`body-parser` が直下にコピーされているため import できてしまい、
「`package.json` には書いていないのに動いてしまうコード」が生まれます。pnpm はこれを構造的に防ぎます。

> もしどうしても npm/yarn 互換のフラットな `node_modules` にしたい場合は `.npmrc` に
> `shamefully-hoist=true` を設定すれば可能ですが、pnpm の利点を打ち消してしまうため推奨されません（[Module 07](../07-dlx-npmrc-ci/README.md) で触れます）。

### 3. ストアの実体共有をハードリンクで確認する

別のディレクトリにもう1つプロジェクトを作り、同じ `express` を追加します。

```bash
cd ..
mkdir project-b && cd project-b
pnpm init
pnpm add express
```

2つのプロジェクトの `express/package.json` の実体（symlink をたどった先）の inode 番号を比較してみましょう。

```bash
stat -c "%i %n" $(readlink -f ../project/node_modules/express/package.json)
stat -c "%i %n" $(readlink -f node_modules/express/package.json)
```

**2つの inode 番号が完全に一致する**はずです。これは OS レベルで「同じファイルの実体」を指している証拠です
（ハードリンク）。つまり `express` の中身は、ディスク上には実質1コピーしか存在せず、
2つのプロジェクトはそこへのリンクを持っているだけです。プロジェクトが増えても、
同じバージョンの依存が増えるだけならディスク使用量はほとんど増えません。

### 4. グローバルストアを見る

```bash
pnpm store path
```

表示されたパス（例: `~/.local/share/pnpm/store/v10`）が実体の置き場所です。中を覗くと、
バージョンごと・ファイル内容のハッシュごとにパッケージが保存されているのが分かります。

```bash
pnpm store status
```

ロックファイルとストアの整合性を確認するコマンドです。壊れている場合は警告が出ます。

## 確認ポイント

- [ ] `node_modules` 直下には `package.json` の直接依存しか現れない
- [ ] `node_modules/.pnpm` の中には間接依存も含めた全パッケージが存在する
- [ ] `package.json` に書いていないパッケージを import すると失敗する
- [ ] 2つの独立したプロジェクトで、同じパッケージの inode 番号が一致する（ハードリンク共有）

## 深掘り課題

- `du -sh node_modules` で `project` と `project-b` それぞれの見た目のディスク使用量を比べてみましょう（ハードリンクなので、実際の追加ディスク消費はごくわずかです）。
- pnpm には `node-linker` という設定があります（`.npmrc` の `node-linker=hoisted` など）。デフォルトの `isolated` 以外のモードがどう違うか、公式ドキュメント https://pnpm.io/npmrc#node-linker を調べてみましょう。

---

前: [01. はじめての pnpm](../01-getting-started/README.md) ｜ 次: [03. workspace でモノレポを作る](../03-workspace-monorepo/README.md)
