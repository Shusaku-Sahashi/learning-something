# 03. workspace でモノレポを作る

## この章のゴール

- `pnpm-workspace.yaml` でモノレポ（複数パッケージ管理）を構成できる
- `workspace:` プロトコルでワークスペース内パッケージ同士を依存させられる
- `pnpm add --workspace` の挙動を理解する

## 事前準備

`project/` には、すでにモノレポの骨組みが用意されています。

```
project/
├── pnpm-workspace.yaml       # このディレクトリ配下をワークスペースとして扱う設定
├── package.json              # ルートの package.json（private: true）
└── packages/
    ├── math-utils/           # 四則演算のユーティリティパッケージ
    │   ├── package.json
    │   └── index.js
    └── cli-app/               # math-utils を使う側のアプリ（まだ依存を追加していない）
        ├── package.json
        └── index.js           # すでに @sample/math-utils を import しているが…
```

`pnpm-workspace.yaml` の中身を見てみましょう。

```yaml
packages:
  - "packages/*"
```

`packages/` 直下の各ディレクトリを、それぞれ独立した npm パッケージ（ワークスペースメンバー）として扱う、という宣言です。

`packages/cli-app/index.js` はすでに `@sample/math-utils` を import するコードになっていますが、
`packages/cli-app/package.json` にはまだ依存関係として書かれていません。この状態でどうなるか確認しましょう。

## ハンズオン

### 1. まずはインストールしてみる

```bash
cd pnpm-course/03-workspace-monorepo/project
pnpm install
```

ワークスペース全体（3つの `importers`）がまとめてインストールされます。

### 2. 依存を追加せずに実行してみる（失敗を体験する）

```bash
pnpm --filter @sample/cli-app start
```

`Cannot find package '@sample/math-utils'` のようなエラーになるはずです。
[Module 02](../02-node-modules-and-store/README.md) で学んだ通り、pnpm は `package.json` に書いていない依存を勝手には見せてくれません。
たとえ同じワークスペース内のパッケージであっても例外ではありません。

### 3. ワークスペース内の依存として追加する

```bash
pnpm add @sample/math-utils --filter @sample/cli-app --workspace
```

- `--filter @sample/cli-app` : `cli-app` パッケージに対してコマンドを実行する
- `--workspace` : 依存の解決先を「npm レジストリ」ではなく「このワークスペース内のパッケージ」に限定する

`packages/cli-app/package.json` を確認してください。

```json
"dependencies": {
  "@sample/math-utils": "workspace:*"
}
```

`workspace:*` は「バージョンに関わらず、常にこのワークスペース内の `math-utils` を使う」という意味のプロトコルです。
公開レジストリには存在しないローカルパッケージでも、モノレポ内では通常の依存と同じように `import` / `require` できます。

### 4. 実行してみる

```bash
pnpm --filter @sample/cli-app start
```

今度は `2 + 3 = 5` / `2 * 3 = 6` が出力されるはずです。

### 5. リンクの実体を確認する

```bash
ls -la packages/cli-app/node_modules/@sample
```

`math-utils -> ../../../math-utils` という symlink になっています。npm レジストリ経由のパッケージと違い、
`math-utils` の実体（`packages/math-utils`）を直接指しているため、`math-utils/index.js` を編集すると
即座に `cli-app` 側にも反映されます（ビルドや再インストールは不要）。

### 6. ロックファイルでの表現を見る

```bash
grep -A3 "cli-app" pnpm-lock.yaml
```

`version: link:../math-utils` のように、通常の npm パッケージ（`registry.npmjs.org` から取得したバージョン番号）とは
異なる形式で記録されているのが分かります。

## workspace: プロトコルのバリエーション

| 指定 | 意味 |
|---|---|
| `workspace:*` | 常にワークスペース内の最新のローカルバージョンを使う |
| `workspace:^` | ワークスペース内のバージョンを、公開時には `^1.2.3` のような通常の semver 範囲に変換する |
| `workspace:~` | 同上、`~1.2.3` 形式に変換する |

`workspace:^` / `workspace:~` は、モノレポ内のパッケージを npm に公開する際に便利です。
`pnpm publish` 時に `workspace:*` が実際のバージョン番号（`^1.0.0` など）に自動置換されるため、
公開後の利用者は普通の semver 依存として `math-utils` をインストールできます。

## 確認ポイント

- [ ] `pnpm-workspace.yaml` に `packages/*` を指定した意味を説明できる
- [ ] `--workspace` フラグの役割を説明できる
- [ ] `workspace:*` がどんな symlink を生むか説明できる
- [ ] `math-utils/index.js` を書き換えると再インストールなしで `cli-app` 側の実行結果が変わることを確認した

## 深掘り課題

- `packages/math-utils/index.js` に `subtract` 関数を追加し、`cli-app/index.js` から呼び出してみましょう（再インストール不要で反映されるはずです）。
- `packages/` にもう1つ `logger` パッケージを作り、`math-utils` から `logger` を `workspace:*` で参照させてみましょう（ワークスペース内パッケージ同士の依存）。

---

前: [02. node_modules の構造とストア](../02-node-modules-and-store/README.md) ｜ 次: [04. フィルタリングとスクリプト実行](../04-filtering-and-scripts/README.md)
