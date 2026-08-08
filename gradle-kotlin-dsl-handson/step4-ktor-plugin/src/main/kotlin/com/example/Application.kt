package com.example

import io.ktor.server.application.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import io.ktor.server.response.*
import io.ktor.server.routing.*

fun main() {
    embeddedServer(Netty, port = 8080) {
        module()
    }.start(wait = true)
}

fun Application.module() {
    routing {
        get("/") {
            call.respondText("Hello from Ktor + Gradle handson (Step4)")
        }
        get("/version") {
            call.respondText(javaClass.`package`.implementationVersion ?: "dev")
        }
    }
}
