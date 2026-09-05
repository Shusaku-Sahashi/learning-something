# Step 4: Ktor 特有のプラグイン理解

`id("io.ktor.plugin")` を適用した、実際に起動する最小 Ktor サーバーアプリ。

## 学ぶ概念(要点)

- `io.ktor.plugin` は内部で **`application` プラグインと `com.gradleup.shadow`(Shadow)プラグインを自動適用**している。だから `application {}` ブロックがそのまま使え、`shadowJar` 相当のタスクも自動で手に入る。
- `io.ktor.plugin` が追加する独自タスク `buildFatJar` / `runFatJar` は、Shadow の `shadowJar` をラップして「Ktor アプリとして実行可能な単一 jar」を作る。
- Ktor のライブラリ(`io.ktor:ktor-server-core` など)にバージョンを書かなくても解決できるのは、プラグインが `io.ktor:ktor-bom` を **constraint(制約)として自動追加**しているから。ただし「強制(enforced)」ではなく「デフォルト値」に近い扱いである点が課題3のポイント。

## 手を動かす課題

### 課題1: fat jar を作って動かす

```bash
./gradlew buildFatJar
ls build/libs/
java -jar build/libs/step4-ktor-plugin-all.jar
# 別ターミナルから
curl localhost:8080/
curl localhost:8080/version
```

### 課題2: `application` プラグインとの関係を確認する

```bash
./gradlew tasks --all
```

出力を「Ktor tasks」「Shadow tasks」「Application tasks」のグループ別に見て、`run` / `runShadow` / `runFatJar` の3つがそれぞれ何を実行しているか、`build.gradle.kts` の `mainClass` 設定とどう関係しているか整理する。

```bash
./gradlew run
```

これも `mainClass.set("com.example.ApplicationKt")` の設定だけで動くことを確認する(= `application` プラグインの機能そのもの)。

### 課題3: バージョン管理の仕組みを検証する

このプロジェクトが使っている `io.ktor.plugin` のバージョンは `3.4.3`(執筆時点の最新は `3.5.2` だが、後述の理由でわざと少し古いものを使っている)。

1. `dependencies` ブロックの `implementation("io.ktor:ktor-server-core")` を、プラグインより**古い**バージョンを明示した形(`implementation("io.ktor:ktor-server-core:3.0.3")`)に書き換える。
2. `./gradlew dependencies --configuration runtimeClasspath | grep ktor-server-core` を実行し、実際に使われるバージョンがどうなるか確認する。
3. 今度はプラグインより**新しい**バージョンを明示した形(`implementation("io.ktor:ktor-server-core:3.5.2")`)に書き換えて同じコマンドを実行する。
4. 2 と 3 で結果がどう違うか比較し、「BOM相当の仕組み」が具体的に何をしているか(`constraint` の役割)を考える。
5. 検証が終わったら `implementation("io.ktor:ktor-server-core")`(バージョン指定なし)に戻す。

(このハンズオンではプラグインを最新の `3.5.2` ではなく `3.4.3` にしているのは、「プラグインより古い/新しい」の両方を、実在する公開バージョンで再現するため。自分のプロジェクトでは基本的に最新の安定版プラグインを使ってよい。)

## 確認ポイント

- `./gradlew tasks --all` に **Ktor tasks** と **Shadow tasks** の両方のグループが出てくること(= io.ktor.plugin が shadow を内部で使っている証拠)
- `buildFatJar` で作った jar を `java -jar` で直接実行でき、`curl localhost:8080/` が通ること
- 課題3で古いバージョンを指定した場合は `3.0.3 -> 3.4.3` のように**プラグインのバージョンに引き上げられる**こと
- 課題3で新しいバージョンを指定した場合は、そちらの**新しいバージョンがそのまま使われる**こと(強制ではなく制約であることの証明)

## つまずきやすいポイント・補足

- `buildFatJar` と `shadowJar` は別タスクだが中身はほぼ同じ。`io.ktor.plugin` が用意しているのは「Ktor アプリ向けに設定済みの shadowJar」というだけで、shadow プラグインを直接 `plugins {}` に書く必要はない。
- fat jar のファイル名が `<projectName>-all.jar` になるのは shadow プラグインのデフォルト命名規則(`archiveClassifier = "all"`)。
- `application` プラグインは Ktor 専用ではなく、Java/Kotlin の一般的な「実行可能アプリケーション」を作るための標準プラグイン。Ktor はこの上に乗っているだけなので、`application` プラグイン単体の知識(Spring Boot ではなく素の Kotlin/Java アプリでも同じ)がそのまま活きる。
- 本番運用では fat jar よりも Docker イメージ化(`io.ktor.plugin` は `buildImage` 等のタスクも提供している)を使うことが多いが、今回は Gradle の理解に集中するためスコープ外にしている。

## 理解度チェック

1. `io.ktor.plugin` を1つ適用するだけで、追加でプラグインを書かなくても使えるようになるプラグインを2つ挙げてください。
2. `io.ktor:ktor-server-core` にバージョンを書かなくてもビルドが通る理由を、Gradle の用語(constraint / platform)を使って説明してください。
3. `implementation("io.ktor:ktor-server-core:3.0.3")` のように意図的に古いバージョンを指定した場合、最終的にどのバージョンが使われますか?またその理由は?
