plugins {
    kotlin("jvm") version "2.3.21"
    application
}

repositories {
    mavenCentral()
}

dependencies {
    testImplementation(kotlin("test"))
}

// この version の値を課題2で書き換えて UP-TO-DATE 判定の変化を観察する
version = "0.1.0"

application {
    mainClass.set("tasksdemo.MainKt")
}

// ============================================================
// カスタムタスク: ビルド情報をファイルに出力する(Ktor の /version エンドポイントなどで
// 使うことを想定した実用パターン)。
//
// Property<String> / RegularFileProperty + @get:Input / @get:OutputFile を使うのが
// 現在推奨されるスタイル(遅延評価でき、Gradle が Input/Output を追跡できる)。
// ============================================================
abstract class GenerateBuildInfoTask : DefaultTask() {

    @get:Input
    abstract val appName: Property<String>

    @get:Input
    abstract val appVersion: Property<String>

    @get:OutputFile
    abstract val outputFile: RegularFileProperty

    @TaskAction
    fun generate() {
        val file = outputFile.get().asFile
        file.parentFile.mkdirs()
        file.writeText(
            """
            app.name=${appName.get()}
            app.version=${appVersion.get()}
            """.trimIndent() + "\n"
        )
        logger.lifecycle("[generateBuildInfo] wrote ${file}")
    }
}

val generateBuildInfo = tasks.register<GenerateBuildInfoTask>("generateBuildInfo") {
    group = "handson"
    description = "app.name / app.version を build-info.properties に書き出す"

    appName.set(project.name)
    // -PappVersion=x.y.z で上書きできるようにしておく(課題2で使う)。
    appVersion.set(providers.gradleProperty("appVersion").orElse(project.version.toString()))
    outputFile.set(layout.buildDirectory.file("generated/buildinfo/build-info.properties"))
}

// generateBuildInfo の出力ディレクトリを、jar に含める resources として追加する。
// これで `./gradlew jar` を実行すると build-info.properties が jar の中に入るようになる。
sourceSets {
    main {
        resources.srcDir(layout.buildDirectory.dir("generated/buildinfo"))
    }
}

// dependsOn: 「このタスクを実行する前に、必ず generateBuildInfo を実行しておく」という宣言。
// これがないと、resources に追加したディレクトリが空のまま processResources が走ってしまうことがある。
tasks.named("processResources") {
    dependsOn(generateBuildInfo)
}

// ------------------------------------------------------------
// 課題3(手を動かす): ここに `printBuildInfo` タスクを自分で追加し、
// generateBuildInfo が生成したファイルの中身を doLast で読んで println する。
// 最後に `generateBuildInfo.configure { finalizedBy(printBuildInfo) }` で接続し、
// `./gradlew generateBuildInfo` を実行するだけで自動的に内容が表示されるようにする。
// 分からなければ README.md の「参考解答」を見ること。
// ------------------------------------------------------------
