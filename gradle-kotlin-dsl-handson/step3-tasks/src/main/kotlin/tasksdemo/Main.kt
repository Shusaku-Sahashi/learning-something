package tasksdemo

fun main() {
    val props = java.util.Properties()
    val stream = Thread.currentThread().contextClassLoader
        .getResourceAsStream("build-info.properties")
        ?: error("build-info.properties が見つかりません。generateBuildInfo タスクは実行されましたか?")

    stream.use { props.load(it) }

    // 本物の Ktor アプリなら、これを GET /version のレスポンスとして返すイメージ
    println("app.name = ${props.getProperty("app.name")}")
    println("app.version = ${props.getProperty("app.version")}")
}
