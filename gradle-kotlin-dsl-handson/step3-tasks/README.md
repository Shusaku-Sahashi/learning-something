# Step 3: タスクの仕組み

## 学ぶ概念(要点)

- 既存タスク(`compileKotlin` / `jar` / `run` など)はすべて何らかのプラグインが登録している。中身は「入力から出力を作る」という意味では自作タスクと同じ。
- `dependsOn`: 「このタスクを実行する前に、指定したタスクを先に実行する」。並び順の保証。
- `finalizedBy`: 「このタスクの後に、指定したタスクを必ず実行する」。対象タスクが**失敗しても**finalizedBy先は実行される(dependsOnとの非対称性がポイント)。
- `@Input` / `@OutputFile` などのアノテーション: Gradle にタスクの「入力」と「出力」を教えることで、**前回と入力が変わっていなければ実行をスキップ(`UP-TO-DATE`)**できるようにする仕組み(インクリメンタルビルドの土台)。

## 手を動かす課題

### 課題1: 既存タスクを観察する

```bash
./gradlew tasks --all
./gradlew tasks --all -q | grep -A2 compileKotlin
./gradlew help --task jar
./gradlew help --task run
```

`compileKotlin` や `jar` がどのグループに属し、どんな説明文が付いているか確認する。

### 課題2: カスタムタスクと UP-TO-DATE を確認する

このプロジェクトには `generateBuildInfo` というカスタムタスクが既にある(`build.gradle.kts` を読んで、何が `@Input` / `@OutputFile` に指定されているか確認すること)。

```bash
./gradlew clean
./gradlew generateBuildInfo        # (1) 初回実行 → 実行される
./gradlew generateBuildInfo        # (2) 2回目 → UP-TO-DATE になるはず
./gradlew generateBuildInfo -PappVersion=0.9.9 --info | grep -i "up-to-date\|has changed"
                                    # (3) appVersion を変えて実行 → 何が原因で再実行されたか --info ログで確認
cat build/generated/buildinfo/build-info.properties
./gradlew generateBuildInfo -PappVersion=0.9.9
                                    # (4) 同じ値でもう一度 → UP-TO-DATE に戻るはず
rm build/generated/buildinfo/build-info.properties
./gradlew generateBuildInfo        # (5) 出力ファイルを消してから実行 → 出力が無いので再実行される
```

### 課題3: `finalizedBy` を自分で書く

`build.gradle.kts` の一番下にヒントコメントがあります。以下を満たす `printBuildInfo` タスクを追加してください。

1. `generateBuildInfo` が生成したファイルを読み込み、内容を `println` する `doLast` 付きタスク `printBuildInfo` を定義する
2. `generateBuildInfo.configure { finalizedBy(printBuildInfo) }` で接続する
3. `./gradlew generateBuildInfo` を実行するだけで、`generateBuildInfo` の後に自動で `printBuildInfo` の出力が表示されることを確認する

**参考解答**(詰まったら見る):

```kotlin
val printBuildInfo = tasks.register("printBuildInfo") {
    group = "handson"
    doLast {
        val file = generateBuildInfo.get().outputFile.get().asFile
        println("---- build-info.properties ----")
        println(file.readText())
        println("--------------------------------")
    }
}
generateBuildInfo.configure {
    finalizedBy(printBuildInfo)
}
```

### 課題4: アプリとして実行する

```bash
./gradlew run
```

`build-info.properties` が `jar`/`resources` に含まれ、アプリの起動時に読み込まれていることを確認する(`processResources` が `generateBuildInfo` に `dependsOn` しているおかげ)。

## 確認ポイント

- `generateBuildInfo` を連続で実行したとき、2回目以降は `UP-TO-DATE` と表示されること
- `-PappVersion=...` で値を変えたときだけ再実行され、`--info` のログに `Value of input property 'appVersion' has changed` と出ること
- 出力ファイルを手動で消すと(内容は同じでも)再実行されること = **出力の有無・内容もタスクの実行判定に使われる**
- `./gradlew run` を実行すると `app.name` / `app.version` が正しく表示されること(dependsOn による自動生成が効いている証拠)

## つまずきやすいポイント・補足

- **カスタムタスククラスを `build.gradle.kts` の中に直接書くと、そのファイルを1文字でも編集しただけで「タスクのクラスパスが変わった」と判定され、無関係な変更でもタスクが再実行される。** これは今回のように学習用に1ファイルにまとめているから起きる話で、実務では `buildSrc/` や Convention Plugin として外に切り出すことで回避するのが一般的。
- `dependsOn` は「順序」を保証するだけで、依存先の出力を自動的に使ってくれるわけではない(今回のように `sourceSets` の resources ディレクトリに追加する等、自分で配線する必要がある)。
- `finalizedBy` は「クリーンアップ処理」(一時ファイルの削除、通知の送信など)に向いている。対象タスクが失敗しても走る点を利用して、例えば「テストが失敗しても必ずレポートを生成する」といった使い方ができる。
- `UP-TO-DATE` はキャッシュではなく「今回は何もしなくていい」という判定。次の Step5 で扱う Build Cache(`FROM-CACHE`)とは別の仕組みなので混同しないこと。

## 理解度チェック

1. `dependsOn` と `finalizedBy` の違いを、対象タスクが失敗した場合の挙動の違いも含めて説明してください。
2. あるタスクが2回目の実行で `UP-TO-DATE` にならなかったとき、原因を特定するために使うコマンドラインオプションは何ですか?
3. `@Input` に指定した値が全く同じでも、タスクが再実行されるのはどんなときですか?
