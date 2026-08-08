# Step 5: ビルドパフォーマンス

`core-lib`(ライブラリ)と `app`(それを使うアプリ)の2モジュール構成。

## 学ぶ概念(要点)

- **Configuration Cache**: Configuration Phase(全 `build.gradle.kts` の評価結果)自体をキャッシュし、2回目以降はスクリプトの評価そのものをスキップする仕組み。効くと `Reusing configuration cache.` と出る。
- **Build Cache**: タスクの**実行結果**(Execution Phase の成果物)を、入力のハッシュ値をキーにして保存する仕組み。`clean` で `build/` ディレクトリを消してもキャッシュは別の場所(`~/.gradle/caches/build-cache-1`)に残るため、`FROM-CACHE` で復元できる。
- **インクリメンタルビルド / コンパイル回避(compile avoidance)**: ソースの一部だけを変更したとき、Kotlin コンパイラは変更のあったファイルだけを再コンパイルする。さらに、公開 API(ABI)に影響しない変更(private メソッドの中身など)なら、**そのモジュールに依存している側は再コンパイルすら不要**になる。

## 手を動かす課題

### 課題1: Configuration Cache の効果を比較する

```bash
./gradlew clean
./gradlew build   # (A) 初回。ログに Configuration Cache の話は出ない
```

`gradle.properties` の `# org.gradle.configuration-cache=true` のコメントを外して有効化する。

```bash
./gradlew clean
./gradlew build   # (B) 1回目 → "Configuration cache entry stored." が出る
./gradlew build   # (C) 2回目 → "Reusing configuration cache." "Configuration cache entry reused." が出る
```

(B) と (C) のログの違い、また体感できるビルド時間の違いを確認する。終わったら再びコメントアウトして戻す。

### 課題2: Build Cache で `FROM-CACHE` を確認する

`gradle.properties` の `# org.gradle.caching=true` のコメントを外して有効化する。

```bash
./gradlew clean
./gradlew build     # (A) 初回実行。compileKotlin は通常どおり実行される
./gradlew clean     # build/ ディレクトリを消す(ただし Build Cache は消えない)
./gradlew build     # (B) 2回目 → compileKotlin が "FROM-CACHE" になるはず
```

### 課題3: インクリメンタルビルドが効くケース・効かないケース

`org.gradle.caching=true` を有効にしたまま進めてよい。

**3-A: private な実装だけを変更する(ABI は変わらない)**

`core-lib/src/main/kotlin/corelib/Calculator.kt` の `private fun compute` の中身だけを書き換える(例: `return a + b` → `return a.plus(b)`)。

```bash
./gradlew build
```

`:core-lib:compileKotlin` は実行されるが、`:app:compileKotlin` が **UP-TO-DATE のまま**であることを確認する。

**3-B: 公開シグネチャを変更する(ABI が変わる)**

`fun add(a: Int, b: Int): Int` を `fun add(a: Int, b: Int, label: String = ""): Int` のようにシグネチャ自体を変更する。

```bash
./gradlew build
```

今度は `:app:compileKotlin` も実行されることを確認する(公開契約が変わったので、依存側の再コンパイルが必要になったため)。

変更後は元のシグネチャに戻しておくこと。

## 確認ポイント

- 課題1: Configuration Cache 無効時には出ない `Configuration cache entry stored.` / `Reusing configuration cache.` が、有効化後の1回目・2回目でそれぞれ出ること
- 課題2: `clean` の後でも `compileKotlin` が `FROM-CACHE` と表示されること(`jar` タスクは対象外になることが多い点は「つまずきやすいポイント」参照)
- 課題3-A: `core-lib:compileKotlin` は実行、`app:compileKotlin` は UP-TO-DATE
- 課題3-B: `core-lib:compileKotlin` と `app:compileKotlin` の両方が実行

## つまずきやすいポイント・補足

- `./gradlew clean build --info | grep -i cach` のように `--info` を付けると、「なぜキャッシュされた/されなかったか」の理由がログに出る。今回の構成だと `jar` タスクには `Caching disabled for task ... because: Not worth caching` と出ることがある。これは Gradle が「このタスクは実行が速すぎてキャッシュの読み書きコストの方が高い」と判断した場合の挙動で、バグではない。
- Configuration Cache と Build Cache は**別の仕組み**。片方だけ有効化することもできるし、両方同時に有効化することもできる。名前が似ているので混同しないこと。
- Configuration Cache は「ビルドスクリプトの中で `Task` オブジェクトを直接参照して実行時に使う」ようなコードがあると無効化されたり警告が出たりする(Task Configuration Avoidance をきちんと守っていないコードとの相性が悪い)。Step1 で学んだ `tasks.register` のような遅延APIを使う理由の1つがここにある。
- コンパイル回避(3-A/3-B)は Kotlin/Java の「クラスファイルの ABI(公開シグネチャ)」を比較して判定される。private メソッドだけでなく、`internal` 関数の中身、コメント、フォーマットの変更なども ABI に影響しないため、下流モジュールは再コンパイルされない。

## 理解度チェック

1. Configuration Cache と Build Cache は、それぞれ「何を」キャッシュしていますか?
2. `clean` を実行してもキャッシュされたタスク結果が失われない理由を説明してください。
3. `private` メソッドの実装だけを変更したとき、そのクラスを使っている別モジュールが再コンパイルされない理由を説明してください。
