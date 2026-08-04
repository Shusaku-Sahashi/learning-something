plugins {
    kotlin("jvm") version "2.0.21"
    application
}

repositories {
    mavenCentral()
}

dependencies {
    // プロジェクト間依存。core の公開 API(GreetingRepository)を使うために implementation で依存する。
    implementation(project(":core"))

    // ロギングファサード。API として直接 import して呼び出すのでコンパイル時に必要 = implementation。
    implementation("org.slf4j:slf4j-api:2.0.17")

    // ロギングの「実装」。consumer のコード上には一切登場しないが、実行時にファサードの裏側で必要になる。
    // compileClasspath には乗らないが runtimeClasspath には乗る。
    runtimeOnly("org.slf4j:slf4j-simple:2.0.17")
}

application {
    mainClass.set("consumer.MainKt")
}
