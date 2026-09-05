# 00. pnpm とは何か

## この章のゴール

- pnpm が npm / yarn と何が違うのかを説明できる
- 「速い」「ディスクを節約できる」と言われる理由をアーキテクチャレベルで理解する
- pnpm 特有の用語（store、ハードリンク、symlink、strict node_modules）に慣れる

## pnpm とは

pnpm (**p**erformant **npm**) は npm 互換の JavaScript パッケージマネージャーです。
`package.json` や多くの CLI コマンド（`install` / `add` / `run` など）は npm と共通の使い方ができますが、
**内部の依存関係の保存方法**が根本的に異なります。

## npm / yarn (classic) との違い

### npm / yarn の node_modules

npm や yarn (v1) は、依存パッケージをフラットな `node_modules` にコピーして展開します。

```
node_modules/
├── express/
├── lodash/
├── ...（express が依存する accepts, body-parser なども全部フラットに並ぶ）
```

これには2つの問題があります。

1. **ディスクの無駄遣い**: 同じバージョンの `lodash` を使うプロジェクトが 10 個あれば、
   ディスク上に 10 個分の `lodash` の実体がコピーされる。
2. **Phantom Dependencies（幽霊依存）**: `node_modules` がフラットなので、
   `package.json` に書いていないパッケージ（依存の依存）まで `require`/`import` できてしまう。
   ある日 express のバージョンが上がって `body-parser` を直接 require するコードが壊れる、といった事故が起きる。

### pnpm の node_modules

pnpm は次の 2 段構えで依存関係を管理します。

1. **content-addressable なグローバルストア** (`~/.local/share/pnpm/store` など) に、
   パッケージの中身をバージョン単位・ファイル単位でただ1つだけ保存する。
2. 各プロジェクトの `node_modules/.pnpm` 以下に、そのストアへの **ハードリンク** を張って実体を再現し、
   さらに **シンボリックリンク** を使って「そのパッケージが直接依存しているものだけ」が見える構造を作る。

```
node_modules/
├── .pnpm/
│   ├── express@4.19.2/node_modules/express -> (実体はストアへのハードリンク)
│   ├── lodash@4.17.21/node_modules/lodash
│   └── ...
├── express -> .pnpm/express@4.19.2/node_modules/express   （symlink）
```

これにより：

- **ディスク効率**: 同じバージョンのファイルはマシン全体で1つしか実体を持たない（ハードリンクなのでコピーコストもほぼゼロ）。
- **インストール速度**: 一度キャッシュされたパッケージはハードリンクを張るだけなので、2回目以降の `pnpm install` が非常に速い。
- **Phantom Dependencies の防止**: `node_modules` 直下には `package.json` に書いた依存だけが symlink される（strict node_modules）。書いていないパッケージを `require` すると `Cannot find module` になる。

この「実体はストアに1つ、プロジェクトからはリンクで参照する」という設計が、pnpm のすべての機能（高速なインストール、モノレポの効率的な運用、依存関係の健全性チェックなど）の土台になっています。

## workspace（モノレポ）サポート

pnpm はモノレポを一級市民として扱います。`pnpm-workspace.yaml` で複数パッケージをまとめて管理し、
パッケージ間の依存を `workspace:` プロトコルで解決できます（詳しくは [Module 03](../03-workspace-monorepo/README.md)）。

## この章の確認（コマンドを打つだけの軽いハンズオン）

実際に pnpm のバージョンとストアの場所を確認してみましょう。

```bash
pnpm --version
pnpm store path
```

`pnpm store path` で表示されたディレクトリが、これから作る全プロジェクトが共有する「実体置き場」です。
複数のプロジェクトで同じパッケージ・バージョンを使っても、ここには1つしか保存されないことを、
[Module 02](../02-node-modules-and-store/README.md) で実際に確認します。

## 深掘り

- 公式ドキュメントの図解: https://pnpm.io/motivation
- pnpm が採用する `node_modules` のレイアウトは [Symlinked node_modules structure](https://pnpm.io/symlinked-node-modules-structure) と呼ばれています。

---

次: [01. はじめての pnpm](../01-getting-started/README.md)
