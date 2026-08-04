plugins {
    kotlin("jvm") version "2.0.21"
    application
}

repositories {
    mavenCentral()
}

dependencies {
    implementation(project(":core-lib"))
}

application {
    mainClass.set("app.MainKt")
}
