# pnpm ハンズオンコース

[pnpm](https://pnpm.io/) の仕組みと主要機能を、実際に手を動かしながら理解するためのコースです。
各モジュールは「概念の説明 → ハンズオン手順 → 確認ポイント → 深掘り課題」の構成になっています。
上から順番に進めることを想定していますが、興味のあるモジュールだけをつまみ食いしても構いません。

## 対象読者

- npm や yarn は使ったことがあるが、pnpm は初めて（または触り始めたばかり）の人
- pnpm が「速い」「ディスクを節約できる」という話は聞いたことがあるが、なぜそうなるのか説明できない人
- モノレポ（workspace）を pnpm で運用してみたい人

## 前提環境

- Node.js 18 以上（このコースは Node.js v22 で動作確認しています）
- ターミナル操作の基本知識
- Git の基本知識（任意）

## pnpm のインストール

このコースでは [Corepack](https://nodejs.org/api/corepack.html) 経由での利用を推奨します。
プロジェクトごとに pnpm のバージョンを固定できるためです。

> **注意**: Corepack は Node.js 16.9〜24 系には同梱されていますが、Node.js TSC の決定により
> **Node.js 25 以降では Node.js 本体には同梱されなくなりました**（非推奨になったわけではなく、あくまで同梱をやめただけです）。
> `node -v` が `v25` 以上の場合は、先に `npm install -g corepack` を実行してから下記のコマンドを使ってください。

```bash
# (Node.js 25 以降のみ) Corepack自体を先にインストール
npm install -g corepack

# Corepack を有効化
corepack enable

# pnpm の最新版を使う場合
corepack use pnpm@latest

# バージョンを確認
pnpm --version
```

Corepack を使わず、npm で直接グローバルインストールする方法もあります。

```bash
npm install -g pnpm
```

## コースの構成

| # | モジュール | 学べること |
|---|-----------|-----------|
| 00 | [pnpm とは何か](./00-introduction/README.md) | npm / yarn との違い、pnpm が採用しているアーキテクチャの概要 |
| 01 | [はじめての pnpm](./01-getting-started/README.md) | `pnpm init` / `add` / `run` など基本コマンド |
| 02 | [node_modules の構造とストア](./02-node-modules-and-store/README.md) | content-addressable store、シンボリックリンク、Phantom Dependencies の防止 |
| 03 | [workspace でモノレポを作る](./03-workspace-monorepo/README.md) | `pnpm-workspace.yaml`、`workspace:` プロトコル |
| 04 | [フィルタリングとスクリプト実行](./04-filtering-and-scripts/README.md) | `--filter`、`-r`（recursive）、`--parallel` |
| 05 | [依存関係の管理](./05-dependency-management/README.md) | `overrides`、peer dependencies、`pnpm why` / `list` / `outdated` |
| 06 | [パッチとカタログ](./06-patch-and-catalog/README.md) | `pnpm patch` による依存関係の直接修正、`catalog:` によるバージョン一元管理 |
| 07 | [dlx・.npmrc・CI 活用](./07-dlx-npmrc-ci/README.md) | `pnpm dlx` / `exec`、`.npmrc` の主要設定、CI でのロックファイル運用 |

## 進め方

各モジュールのディレクトリには、そのまま `pnpm install` や `pnpm run` を試せるサンプルプロジェクトが `project/` 配下に入っています。

```bash
cd pnpm-course/01-getting-started/project
pnpm install
```

`node_modules` や `pnpm-lock.yaml` は基本的に `.gitignore` されているため、何度でも `pnpm install` からやり直せます。手順を壊してしまっても、`git checkout -- .` や該当ファイルの削除で元の状態に戻せます。

それでは [00. pnpm とは何か](./00-introduction/README.md) から始めましょう。
