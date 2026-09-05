package corelib

class Calculator {
    // 公開 API(シグネチャ)。課題3-A ではここは変えない。
    fun add(a: Int, b: Int): Int = compute(a, b)

    // private なので ABI(公開契約)には影響しない = ここだけ変えても
    // このクラスを使う側(app モジュール)は再コンパイル不要になるはず、というのが課題3-Aの検証。
    private fun compute(a: Int, b: Int): Int {
        return a + b
    }
}
