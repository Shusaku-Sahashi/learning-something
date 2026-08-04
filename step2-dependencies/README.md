# Step 2: 依存関係管理

構成: `core`(ライブラリモジュール)と `consumer`(アプリモジュール、`core` に依存)の2モジュール構成。

## 学ぶ概念(要点)

- **`implementation` vs `api`**: どちらも「コンパイル時 + 実行時に必要」という点は同じだが、
  - `api` で宣言した依存は、そのモジュールを使う側(downstream)の**コンパイルクラスパスにも伝播する**
  - `implementation` は伝播しない(そのモジュールの内部実装として隠蔽される)
  - → `api` を使いすぎると、依存グラフ全体が密結合になり、ライブラリのバージョンを1つ上げただけで無関係なモジュールまで再コンパイルが走るようになる。**基本は `implementation`、公開APIの型として本当に露出する依存だけ `api`**、が原則。
- **`compileOnly`**: コンパイル時にしか要らない依存(実行時クラスパスにもjarにも含まれない)
- **`runtimeOnly`**: 実行時にしか要らない依存(コンパイル時クラスパスには含まれない)
- **バージョンカタログ(`libs.versions.toml`)**: 依存のバージョン番号を1箇所にまとめ、`libs.guava` のように型安全にアクセスできる仕組み

## 手を動かす課題

### 課題1: `api` と `implementation` の挙動差を体感する

1. `./gradlew :consumer:run` を実行して正常に動くことを確認する。
2. `core/build.gradle.kts` の `api("com.google.guava:guava:...")` を `implementation(...)` に書き換える。
3. `./gradlew :consumer:compileKotlin` を実行する → **コンパイルエラーになることを確認する**(`consumer/Main.kt` が `ImmutableList` 型を直接参照しているため)。
4. なぜエラーになったか、エラーメッセージから読み取る。
5. `api(...)` に戻して再度ビルドが通ることを確認する。

### 課題2: バージョンカタログを導入する(Before → After)

1. 現在の `core/build.gradle.kts` と `consumer/build.gradle.kts` は、バージョン番号が直接ハードコードされている状態(Before)。
2. `gradle/libs.versions.toml` を新規作成し、`kotlin` / `guava` / `org.jetbrains:annotations` / `slf4j-api` / `slf4j-simple` のバージョンを `[versions]` セクションに、ライブラリ座標を `[libraries]` セクションに、Kotlin プラグインを `[plugins]` セクションに定義する。
3. `core/build.gradle.kts` と `consumer/build.gradle.kts` を `libs.xxx` / `alias(libs.plugins.xxx)` を使う形に書き換える。
4. `./gradlew build` が Before と同じように通ることを確認する。
5. 答え合わせ: `libs.versions.toml.after-example`(このディレクトリ直下)を見る。これは Gradle には読み込まれない参考ファイル。

### 課題3: 依存関係を可視化する

以下のコマンドをそれぞれ実行し、出力の違いを観察する。

```bash
# core が実際に何をコンパイル時 / 実行時に使っているか
./gradlew :core:dependencies --configuration compileClasspath
./gradlew :core:dependencies --configuration runtimeClasspath

# consumer 側から見えている依存(core 経由で漏れてくる guava に注目)
./gradlew :consumer:dependencies --configuration compileClasspath
./gradlew :consumer:dependencies --configuration runtimeClasspath

# 特定のライブラリがどの経路で解決されているかを深掘りする
./gradlew :consumer:dependencyInsight --dependency guava --configuration compileClasspath
```

## 確認ポイント

- `core:compileClasspath` には `org.jetbrains:annotations:26.1.0`(compileOnly で指定したバージョン)が出るが、`core:runtimeClasspath` にはそのバージョンが**出てこない**こと(compileOnly は実行時に伝播しない)
- `consumer:compileClasspath` には `slf4j-simple` が**出てこない**が、`consumer:runtimeClasspath` には**出てくる**こと(runtimeOnly はコンパイル時に伝播しない)
- `consumer:compileClasspath` に `com.google.guava:guava` が(consumer 自身は依存を宣言していないのに)出てくること = `core` が `api` で公開しているから

## つまずきやすいポイント・補足

- `implementation` に変えてもエラーが消えない場合、`consumer` 側にも直接 `implementation("com.google.guava:...")` を書けば解決するが、これは「`core` の実装詳細だったはずの Guava に `consumer` が直接依存する」ことを意味する。本来は「`core` の戻り値の型に外部ライブラリの型を露出させない」ように設計を見直すのが王道(例: `List<String>` を返す、独自の値オブジェクトでラップする、など)。
- `compileOnly` の典型的な実務例は、Lombok のようなアノテーション処理系や、Servlet API のように「実行環境(Webコンテナ)側が提供してくれるので自分では持ち込みたくない」依存。
- `runtimeOnly` の典型的な実務例は、今回の `slf4j-api`(facade) + `slf4j-simple`(実装)のようなロギング実装の差し替えや、JDBCドライバ。
- バージョンカタログの `[versions]` のキー名にハイフンを使うと Kotlin DSL 側からは `libs.versions.jetbrainsAnnotations`(キャメルケース)のようにアクセスすることになる点に注意。

## 理解度チェック

1. `implementation` ではなく `api` を使うべきなのはどんな時か、具体例を挙げて説明してください。
2. `compileOnly` で宣言した依存は、そのモジュールが作る jar ファイルの中身にどう影響しますか?
3. バージョンカタログを導入する主なメリットを、複数モジュール構成の観点から説明してください。
