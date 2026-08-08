# Step 1: Gradle の基本モデル

## 学ぶ概念(要点)

- **Project / Task / Plugin** の関係
  - `Project` はビルド対象そのもの(このディレクトリ = `:` という1つの Project)
  - `Plugin` は Project に対して `Task` や設定(拡張機能、`repositories`, `dependencies` の書き方など)をまとめて追加するもの
  - `Task` は実際の作業単位。`plugins {}` で入れた `kotlin("jvm")` は `compileKotlin` や `test` などのタスクを大量に追加してくれる
- **ビルドライフサイクル**: `Initialization → Configuration → Execution` の3段階
  - Initialization: `settings.gradle.kts` を読み、どの Project がビルドに参加するか決める
  - Configuration: 参加する全 Project の `build.gradle.kts` を評価する(トップレベルの `println` やタスク登録ブロックの中身がここで走る)
  - Execution: 実行対象に選ばれたタスクの `doFirst` / `doLast` / `@TaskAction` が実際に走る
- **Kotlin DSL 特有の書き方**
  - `tasks.register<T>("name") { ... }`: 型安全 + 遅延登録(Task Configuration Avoidance)。ラムダは「そのタスクが本当に必要になるまで」実行されない
  - `DefaultTask` や `@TaskAction` は import 不要(Kotlin DSL のデフォルトインポートに含まれる)
  - Groovy DSL の `task greet(type: GreetTask) { ... }` は動的型付けで実行時までタイプミスに気づけないが、Kotlin DSL は IDE 補完とコンパイルエラーで守られる

## 手を動かす課題

1. `./gradlew help` を実行し、ログの中で `[Initialization]` → `[Configuration]` がどの順番で出るか確認する。
2. `./gradlew lifecycleDemo` を実行し、`[Configuration]` → `doFirst` → `doLast` の順にログが出ることを確認する。
3. `./gradlew chained` を実行する。`greet` タスクを直接指定していないのに `greet` の `[Execution]` ログが出る理由を `dependsOn(greet)` から説明できるようにする。
4. `./gradlew lifecycleDemo` だけを実行したとき、`greet` タスクの `[Configuration]` ログが **出ない** ことを確認する。次に `./gradlew tasks --group handson` を実行し、今度は `greet` と `lifecycleDemo` の両方の `[Configuration]` ログが出ることを確認する。この違いが何を意味するか考える。
5. `build.gradle.kts` の `greet` タスク定義を、`tasks.register<GreetTask>` から `tasks.create<GreetTask>`(即時生成)に書き換えて同じ手順を試し、ログの出るタイミングがどう変わるか比較する(終わったら `register` に戻しておく)。

## 確認ポイント

- `[Initialization]` のログは `settings.gradle.kts` に書いたものなので、**どのタスクを実行しても必ず一番最初に出る**こと
- `./gradlew <個別タスク名>` を実行したときは、**依存関係にあるタスクの Configuration ブロックだけ**が評価されること(課題4)
- `dependsOn` で繋いだタスクは、`chained` を実行しただけで `greet` の Execution が先に走ること

## つまずきやすいポイント・補足

- **`register` と `create` の違い**: `register` は遅延(必要になるまでインスタンス化しない)、`create` は即時。大規模プロジェクトでは `register` を使わないと、使わないタスクまで全部設定してビルドが遅くなる。迷ったら `register` を使う。
- **`plugins {}` ブロックは特別扱い**: 通常の Kotlin コードのように変数を参照したり `if` 文を書いたりできない(静的解析でプラグインとバージョンを事前解決するため)。動的な条件分岐が必要な場合は `apply(plugin = "...")` を使うが、型安全性が失われるので基本は避ける。
- **`println` はデバッグ用**: 本番の設定では `logger.lifecycle(...)` / `logger.info(...)` など Gradle のロギング API を使うのが正しい。今回は現象を分かりやすくするためだけに `println` を使っている。
- Groovy DSL との違いは「動的 vs 静的型付け」だけでなく、`build.gradle` → `build.gradle.kts` のようにファイル名でパーサーが切り替わる点も覚えておくと良い。

## 理解度チェック

1. `Initialization` フェーズと `Configuration` フェーズの違いを、それぞれ何が読み込まれ・何が実行されるかで説明してください。
2. `tasks.register<T>("name") { ... }` の `{ ... }` ブロックは、いつ評価されますか?「ビルドスクリプトを読み込んだ瞬間」ではない理由を説明してください。
3. Groovy DSL ではなく Kotlin DSL を使う技術的なメリットを2つ挙げてください。
