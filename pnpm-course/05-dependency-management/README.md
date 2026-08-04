# 05. 依存関係の管理

## この章のゴール

- `pnpm why` で「なぜこのパッケージが入っているか」を調査できる
- `pnpm list` / `pnpm outdated` で依存関係の現状を把握できる
- peer dependencies の自動インストールの挙動を理解する
- `pnpm.overrides` で間接依存のバージョンを強制的に上書きできる

## ハンズオン

### 1. まずはインストール

`project/package.json` には、あえて少し古い `express@4.18.0` が固定されています。

```bash
cd pnpm-course/05-dependency-management/project
pnpm install
```

### 2. 何が古くなっているか調べる（`pnpm outdated`）

```bash
pnpm outdated
```

`express` の `Current`（今入っているバージョン）と `Latest`（レジストリ上の最新版）が表の形式で表示されます。
（更新可能なパッケージがある場合、`pnpm outdated` は終了コード `1` を返します。CI で「更新忘れがないか」をチェックする用途にも使えます。）

### 3. 依存ツリーを俯瞰する（`pnpm list`）

```bash
pnpm list
pnpm list --depth 2
```

`--depth` を増やすほど、間接依存まで深く表示されます。

### 4. 「なぜこのパッケージが入っているのか」を調べる（`pnpm why`）

`express` は内部で `qs`（クエリ文字列パーサー）に依存しています。直接 `package.json` には書いていないこのパッケージが、
どういう経路でインストールされているのか調べてみましょう。

```bash
pnpm why qs
```

```
qs@6.10.3
├─┬ body-parser@1.20.0
│ └─┬ express@4.18.0
│   └── dependency-management-demo@1.0.0 (dependencies)
└── express@4.18.0 [deduped]
```

このように「誰が」「どの経路で」そのパッケージを要求しているかが木構造で表示されます。
意図しないバージョンの脆弱なパッケージが紛れ込んでいないかを調べるときの基本コマンドです。

### 5. peer dependencies の自動解決を観察する

React 用の状態管理ライブラリ `react-redux` を追加してみます。これは `react` を peer dependency として要求しますが、
`react` 自体はまだこのプロジェクトに入っていません。

```bash
pnpm add react-redux
```

npm では「peer dependency が見つかりません」という警告が出るところですが、pnpm はデフォルト設定
（`auto-install-peers=true`）により、解決可能な peer dependency を自動的にインストールします。

```bash
pnpm why react
```

`react` が `react-redux` の peer として自動的に解決されているのが分かります。ただし、これはあくまで
「`react-redux` が内部で使うために」解決されたものです。あなたのアプリコード側から `react` を直接 `import` できるかを
確認してみましょう。

```bash
cat > check-react.mjs << 'EOF'
try {
  await import("react");
  console.log("react を直接 import できてしまった");
} catch (e) {
  console.log("直接 import 不可 (想定通り):", e.code);
}
EOF
node check-react.mjs
```

自動インストールされた peer dependency も、[Module 02](../02-node-modules-and-store/README.md) で学んだ
Phantom Dependency 防止の対象です。`package.json` に自分で `react` を追加しない限り、直接使うことはできません。

後片付けをしておきましょう。

```bash
pnpm remove react-redux
```

### 6. overrides で間接依存のバージョンを固定する

`qs` のバージョンを、express が要求するバージョンとは関係なく強制的に固定してみます。
`package.json` に `pnpm.overrides` フィールドを追加してください。

```json
{
  "dependencies": {
    "express": "4.18.0"
  },
  "pnpm": {
    "overrides": {
      "qs": "6.11.0"
    }
  }
}
```

（もし手順4の時点ですでに `qs@6.11.0` だった場合は `"6.9.7"` など別バージョンで試してください。）

```bash
pnpm install
pnpm why qs
```

`overrides` に書いたバージョンが優先されているのが確認できます。これは、依存先のパッケージ（今回は express）が
指定しているバージョン範囲よりも、あなたのプロジェクトの `pnpm.overrides` が優先されるためです。
セキュリティ脆弱性が報告された間接依存を、パッチ版がリリースされるまでの応急処置として固定する、といった用途で使います。

## npm / yarn との違いに関する補足

- npm でも `overrides` フィールド（`package.json` 直下）で同様のことができますが、pnpm では `pnpm.overrides` の中に書きます。
- yarn (Berry) には `resolutions` という同様の機能があります。

## 確認ポイント

- [ ] `pnpm why <pkg>` で依存経路を読める
- [ ] `pnpm outdated` の出力の見方が分かる
- [ ] peer dependency がデフォルトで自動インストールされることを確認した
- [ ] 自動インストールされた peer dependency も、直接 import はできない（strict node_modules の対象）ことを確認した
- [ ] `pnpm.overrides` で間接依存のバージョンを固定できることを確認した

## 深掘り課題

- `.npmrc` に `auto-install-peers=false` を設定すると、手順5はどう変わるか試してみましょう（peer dependency が自動解決されなくなり、警告が表示されるようになります）。
- `pnpm.overrides` には `"express>qs": "6.11.0"` のように「どの依存経路の qs か」を指定する記法もあります。複数のパッケージが異なるバージョンの `qs` を要求している状況を作り、経路を指定した overrides を試してみましょう。

---

前: [04. フィルタリングとスクリプト実行](../04-filtering-and-scripts/README.md) ｜ 次: [06. パッチとカタログ](../06-patch-and-catalog/README.md)
