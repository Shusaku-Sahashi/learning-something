plugins {
    kotlin("jvm") version "2.0.21"
    // io.ktor.plugin は「application プラグイン」の上に乗っかっていて、
    // 加えて fat jar 作成タスク(buildFatJar)や Docker 関連タスクを追加してくれる。
    id("io.ktor.plugin") version "3.0.3"
}

group = "com.example"
version = "0.1.0"

repositories {
    mavenCentral()
}

dependencies {
    // ポイント: io.ktor:* のライブラリにバージョンを書いていない。
    // io.ktor.plugin を適用すると、プラグインのバージョン(3.0.3)に合わせて
    // 全 Ktor ライブラリのバージョンを揃えてくれる BOM 相当の仕組みが自動で効くため。
    implementation("io.ktor:ktor-server-core")
    implementation("io.ktor:ktor-server-netty")
    implementation("ch.qos.logback:logback-classic:1.5.12")

    testImplementation("io.ktor:ktor-server-test-host")
    testImplementation(kotlin("test"))
}

application {
    // io.ktor.plugin は application プラグインを内部で適用しているので、
    // mainClass を設定すれば ./gradlew run がそのまま使える。
    mainClass.set("com.example.ApplicationKt")
}
