# Gradle Kotlin DSL ハンズオン

Kotlin + Ktor でサーバーサイド開発をしている人向けに、Gradle(特に Kotlin DSL / `build.gradle.kts`)を体系的に学ぶためのハンズオンです。「なんとなくコピペで動いている」状態から、「各行がなぜそう書かれているか説明できる」状態を目指します。

## 前提

- JDK 17〜26(各プロジェクトの Gradle Wrapper が Gradle 9.6.1 を自動ダウンロードします。Gradle 9 系の実行には JVM 17 以上が必要です)
- インターネット接続(Maven Central からの依存解決、Gradle Wrapper のダウンロードに必要)
- 各ステップは**独立した Gradle プロジェクト**です。それぞれのディレクトリに `cd` してから `./gradlew ...` を実行してください。

## 進め方

1. Step1 から順番に、各ディレクトリの `README.md` を読みながら進めてください(コードとコマンドを中心に、説明は最小限にしています)。
2. 各ステップの最後に「理解度チェック」があります。コードを見返さずに答えられるか確認してください。
3. 詰まったら README 内の「参考解答」やコメントのヒントを見てから進めてください。

## ステップ一覧

| Step | ディレクトリ | 学ぶこと |
|---|---|---|
| 1 | [`step1-basics/`](./step1-basics) | Project / Task / Plugin の関係、Initialization → Configuration → Execution のライフサイクル、Kotlin DSL 特有の書き方(`tasks.register<T>` など) |
| 2 | [`step2-dependencies/`](./step2-dependencies) | `implementation` / `api` / `compileOnly` / `runtimeOnly` の違い、バージョンカタログ(`libs.versions.toml`)、`dependencies` / `dependencyInsight` |
| 3 | [`step3-tasks/`](./step3-tasks) | カスタムタスクの作り方、`dependsOn` / `finalizedBy`、`@Input` / `@OutputFile` と `UP-TO-DATE` 判定 |
| 4 | [`step4-ktor-plugin/`](./step4-ktor-plugin) | `io.ktor.plugin` による fat jar ビルド、`application` プラグインとの関係、Ktor のバージョン管理(BOM相当の仕組み) |
| 5 | [`step5-performance/`](./step5-performance) | Configuration Cache、Build Cache(`FROM-CACHE`)、インクリメンタルビルド/コンパイル回避 |

## 各ステップの構成

すべてのステップに以下が含まれています。

- `README.md`: そのステップで学ぶ概念の要点、手を動かす課題、確認ポイント、つまずきやすいポイント、理解度チェック
- 動作確認済みの `build.gradle.kts`(と関連ソース)
- Gradle Wrapper(`./gradlew`)

課題で `build.gradle.kts` を書き換えても、`git diff` で元の状態と比較したり、`git checkout -- .` でいつでも初期状態に戻せます。
