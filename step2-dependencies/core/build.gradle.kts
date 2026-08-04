plugins {
    kotlin("jvm") version "2.0.21"
}

repositories {
    mavenCentral()
}

dependencies {
    // --- 課題1で書き換える対象 -------------------------------------------
    // api にすると、core を使う側(consumer)のコンパイルクラスパスにも Guava が「漏れ出す」。
    // implementation にすると、Guava は core の内部実装にしか使われず、consumer からは見えなくなる。
    api("com.google.guava:guava:33.6.0-jre")

    // コンパイル時だけ必要で、実行時には要らない依存の例(アノテーションプロセッサ等でよく使うパターン)。
    // jar には含まれず、実行時クラスパスにも伝播しない。
    compileOnly("org.jetbrains:annotations:26.1.0")
}
