plugins {
    kotlin("jvm") version "2.3.21"
    // io.ktor.plugin は「application プラグイン」の上に乗っかっていて、
    // 加えて fat jar 作成タスク(buildFatJar)や Docker 関連タスクを追加してくれる。
    //
    // 執筆時点の最新は 3.5.2 だが、このハンズオンでは意図的に少し前の 3.4.3 を使う。
    // 理由は課題3で「プラグインより古いバージョン」と「プラグインより新しいバージョン」の
    // 両方を実際に存在する公開バージョンで検証できるようにするため(詳しくは Step4 の README参照)。
    id("io.ktor.plugin") version "3.4.3"
}

group = "com.example"
version = "0.1.0"

repositories {
    mavenCentral()
}

dependencies {
    // ポイント: io.ktor:* のライブラリにバージョンを書いていない。
    // io.ktor.plugin を適用すると、プラグインのバージョン(3.4.3)に合わせて
    // 全 Ktor ライブラリのバージョンを揃えてくれる BOM 相当の仕組みが自動で効くため。
    implementation("io.ktor:ktor-server-core")
    implementation("io.ktor:ktor-server-netty")
    implementation("ch.qos.logback:logback-classic:1.6.1")

    testImplementation("io.ktor:ktor-server-test-host")
    testImplementation(kotlin("test"))
}

application {
    // io.ktor.plugin は application プラグインを内部で適用しているので、
    // mainClass を設定すれば ./gradlew run がそのまま使える。
    mainClass.set("com.example.ApplicationKt")
}
