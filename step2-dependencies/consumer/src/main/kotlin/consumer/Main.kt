package consumer

import com.google.common.collect.ImmutableList
import core.GreetingRepository
import org.slf4j.LoggerFactory

private val logger = LoggerFactory.getLogger("consumer.Main")

fun main() {
    // ImmutableList は Guava の型。consumer 自身は Guava に依存を書いていないのに
    // この型を直接使えているのは、core が Guava を `api` で公開しているから(課題1で検証する)。
    val greetings: ImmutableList<String> = GreetingRepository().greetings(suffix = "!")

    greetings.forEach { logger.info(it) }
}
