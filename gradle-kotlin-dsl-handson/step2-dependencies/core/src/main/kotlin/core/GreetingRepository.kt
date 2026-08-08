package core

import com.google.common.collect.ImmutableList
import org.jetbrains.annotations.NotNull

/**
 * core モジュールの公開 API。
 * 戻り値の型に Guava の ImmutableList を使っている点が今回のポイント。
 */
class GreetingRepository {

    // @NotNull は compileOnly 依存(org.jetbrains:annotations)。
    // コンパイル時にしか参照されないので実行時クラスパスに annotations jar が無くても動く。
    fun greetings(@NotNull suffix: String): ImmutableList<String> =
        ImmutableList.of("Hello$suffix", "Gradle$suffix")
}
