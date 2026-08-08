rootProject.name = "step5-performance"

include(":core-lib")
include(":app")

// ローカル Build Cache を有効化する(誰の環境でも同じように試せるよう、
// リモートキャッシュではなく `~/.gradle/caches/build-cache-1` を使うローカルキャッシュにしている)。
buildCache {
    local {
        isEnabled = true
    }
}
