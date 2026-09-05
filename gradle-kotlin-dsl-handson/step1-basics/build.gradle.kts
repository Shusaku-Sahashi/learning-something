// ============================================================
// このファイル自体が「Configuration Phase」に評価されるコードです。
// トップレベルに書いた println はビルドのたびに(タスクを実行しなくても)必ず走ります。
// 試しに `./gradlew help` を実行して、どのログがいつ出るか観察してください。
// ============================================================

println("[Configuration] build.gradle.kts の評価を開始します")
println("[Configuration] project.name = ${project.name}, project.path = ${project.path}")

plugins {
    // Kotlin DSL の `plugins {}` ブロックは特殊で、ここで書ける内容は限定されています
    // (プラグインの適用だけを宣言する専用のブロック = 型安全にバージョン解決するため)
    kotlin("jvm") version "2.3.21"
}

println(
    "[Configuration] kotlin(\"jvm\") 適用後の plugins = " +
        project.plugins.joinToString { it.javaClass.simpleName }
)

repositories {
    mavenCentral()
}

dependencies {
    testImplementation(kotlin("test"))
}

// ------------------------------------------------------------
// カスタムタスクその1: Task クラスを自分で定義する書き方
// DefaultTask も @TaskAction も org.gradle.api / org.gradle.api.tasks の
// デフォルトインポートに含まれているため import 文は不要です(Kotlin DSL の特徴)
// ------------------------------------------------------------
abstract class GreetTask : DefaultTask() {
    @TaskAction
    fun greet() {
        println("[Execution] GreetTask が実行されました (${this.name})")
    }
}

// tasks.register<T>(name) { ... }
// → Kotlin DSL 特有の「型安全な遅延タスク登録」。
//   register は Task Configuration Avoidance(タスクを実際に使うまでインスタンス化しない)の仕組みで、
//   Groovy DSL の task greet(type: GreetTask) { ... } に相当します。
//   ここで渡すラムダは「タスクが必要になった時」まで実行されません = Configuration Phase の中でも遅延評価。
val greet = tasks.register<GreetTask>("greet") {
    group = "handson"
    description = "GreetTask を実行するカスタムタスク"
    println("[Configuration] greet タスクの設定ブロックが評価されました")
}

// カスタムタスクその2: 名前無しの Task 型に対して doFirst/doLast でアクションを積む素朴な書き方
tasks.register("lifecycleDemo") {
    group = "handson"
    description = "Initialization/Configuration/Execution を println で観察するタスク"

    println("[Configuration] lifecycleDemo タスクの設定ブロックが評価されました")

    doFirst {
        println("[Execution] lifecycleDemo の doFirst が実行されました")
    }
    doLast {
        println("[Execution] lifecycleDemo の doLast が実行されました")
    }
}

// dependsOn でタスク同士をつなぐ (Step3 で詳しく扱いますが、ここでは雰囲気だけ)
tasks.register("chained") {
    group = "handson"
    dependsOn(greet)
    doLast {
        println("[Execution] chained タスクが実行されました (greet の後に実行される)")
    }
}
