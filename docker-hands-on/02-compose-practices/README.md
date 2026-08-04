# 02. Docker Composeの実践的な機能

このディレクトリ(`02-compose-practices/`)の中で作業します。01で改善したDockerfile
(`../solutions/01-dockerfile-quality/Dockerfile`)を使い、Redis付きのWebアプリを
Composeで正しく組み立てていきます。

このディレクトリに、まず土台となる `docker-compose.yml` を新規作成してください。

```yaml
services:
  redis:
    image: redis:7-alpine

  web:
    build:
      context: ../app
      dockerfile: ../solutions/01-dockerfile-quality/Dockerfile
    environment:
      REDIS_HOST: redis
    ports:
      - "8000:8000"
    depends_on:
      - redis
```

一度動かしてみます。

```bash
cd docker-hands-on/02-compose-practices
docker compose up -d --build
curl -s http://localhost:8000/
docker compose down
```

動きはしますが、以下4点が実務レベルには足りません。順番に改善していきます。

---

## Step 1: `depends_on` の `condition: service_healthy`

### なぜ重要か

デフォルトの `depends_on: [redis]` は「起動順序」しか保証しません。Redisの**コンテナが起動した
瞬間**にwebコンテナも起動してしまうため、Redisがまだ接続を受け付ける準備(初期化処理など)が
できていないタイミングでwebがRedisに繋ぎに行き、起動直後だけ接続エラーになる、という
不安定な事故が実務でよく起きます(特にDBの初期化に時間がかかるMySQL/Postgresで顕著)。
`condition: service_healthy` を使うと、「依存先のHEALTHCHECKが `healthy` になるまで
このサービスを起動しない」という**本当に必要な依存関係**を表現できます。
これが01で作った `HEALTHCHECK` が実際に活きてくる場面です。

### 手を動かす

```diff
 services:
   redis:
     image: redis:7-alpine
+    healthcheck:
+      test: ["CMD", "redis-cli", "ping"]
+      interval: 5s
+      timeout: 3s
+      retries: 5
+      start_period: 5s
 
   web:
     build:
       context: ../app
       dockerfile: ../solutions/01-dockerfile-quality/Dockerfile
     environment:
       REDIS_HOST: redis
     ports:
       - "8000:8000"
-    depends_on:
-      - redis
+    depends_on:
+      redis:
+        condition: service_healthy
```

### 動作確認

```bash
docker compose up -d --build
docker compose ps
```

`redis` の `STATUS` に `(healthy)` が出ていること、そして `web` が `redis` が
healthyになるまでコンテナ作成すらされないことを確認します。以下でそれを体感できます。

```bash
docker compose down
docker compose up -d redis
docker compose ps
# この時点ではwebはまだ存在しない
docker compose up -d web
docker compose ps
```

`docker compose up -d` を最初から実行した場合の `docker compose events` を見ると、
`redis` が `health_status: healthy` になったあとに `web` の `create` イベントが
発生していることも確認できます(余裕があれば試してください)。

```bash
docker compose down
```

---

## Step 2: `profiles` による環境の出し分け

### なぜ重要か

開発時だけ使いたいデバッグ用ツール(GUI管理画面など)を常時起動する構成にしてしまうと、
「本番相当の検証環境なのに開発ツールが動いている」「CI実行時に不要なコンテナの起動待ちで
遅くなる」といった問題が起きます。`profiles` を使うと、明示的に指定しない限り
起動しないサービスを定義でき、「普段は最小構成、必要な時だけ `--profile` で追加」
という運用ができます。

### 手を動かす

Redisの中身をGUIで見られる `redis-commander` を、通常時は起動しない
デバッグ専用サービスとして追加します。

```diff
 services:
   redis:
     image: redis:7-alpine
     healthcheck:
       test: ["CMD", "redis-cli", "ping"]
       interval: 5s
       timeout: 3s
       retries: 5
       start_period: 5s
 
   web:
     build:
       context: ../app
       dockerfile: ../solutions/01-dockerfile-quality/Dockerfile
     environment:
       REDIS_HOST: redis
     ports:
       - "8000:8000"
     depends_on:
       redis:
         condition: service_healthy
+
+  redis-commander:
+    image: rediscommander/redis-commander:latest
+    profiles: ["debug"]
+    environment:
+      REDIS_HOSTS: local:redis:6379
+    ports:
+      - "8081:8081"
+    depends_on:
+      redis:
+        condition: service_healthy
```

### 動作確認

```bash
docker compose up -d
docker compose ps
# redis-commanderは起動していないはず

docker compose --profile debug up -d
docker compose ps
# redis-commanderも起動する。 http://localhost:8081 で確認できる

docker compose --profile debug down
```

`--profile debug` を付けない限り `redis-commander` が一切起動しないことがポイントです。

---

## Step 3: 複数composeファイルの合成(override)

### なぜ重要か

「開発環境ではソースをbind mountしてホットリロードしたい」「本番環境ではリソース制限や
再起動ポリシーを入れたい」といった差分を、1つの `docker-compose.yml` に `environment`
別のif分岐のような形で詰め込むと、すぐに可読性が破綻します。Composeは複数ファイルを
**上書き合成**できるので、共通部分を `docker-compose.yml` に、環境固有の差分を
別ファイルに分離するのが実務での定石です。

- `docker-compose.override.yml` という名前のファイルは `docker compose up` 実行時に
  **自動で** ベースファイルに合成されます(主に開発用)
- それ以外の名前(例: `docker-compose.prod.yml`)は `-f` で明示的に指定しない限り読み込まれません

### 手を動かす

開発用の上書き(`docker-compose.override.yml`)を新規作成します。

```yaml
services:
  web:
    volumes:
      - ../app:/app
    environment:
      FLASK_DEBUG: "1"
```

本番用(`docker-compose.prod.yml`)も新規作成します。

```yaml
services:
  web:
    restart: unless-stopped
    environment:
      FLASK_DEBUG: "0"
    deploy:
      resources:
        limits:
          cpus: "0.50"
          memory: 256M
```

### 動作確認

まず「合成結果」を実際に流し込む前に確認できます。これが実務での差分デバッグの基本手技です。

```bash
# 開発モード(override.ymlが自動合成される)
docker compose config | grep -A3 "volumes:"
# ../app:/app のbind mountが合成結果に含まれていることを確認

docker compose up -d
docker compose exec web env | grep FLASK_DEBUG
# => FLASK_DEBUG=1

docker compose down
```

```bash
# 本番モード(override.ymlを無視し、prod.ymlを明示合成)
docker compose -f docker-compose.yml -f docker-compose.prod.yml config | grep -A2 "resources:"
# cpus/memory制限が合成結果に含まれていることを確認

docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
docker compose -f docker-compose.yml -f docker-compose.prod.yml exec web env | grep FLASK_DEBUG
# => FLASK_DEBUG=0(bind mountもされていないはず)

docker compose -f docker-compose.yml -f docker-compose.prod.yml down
```

「同じ `docker-compose.yml` をベースに、ファイルの組み合わせだけで開発/本番を切り替えられる」
ことが体感できればこのステップは完了です。

---

## Step 4: `.env` ファイルでの機密情報管理

### なぜ重要か

Redisのパスワードのような機密情報を `docker-compose.yml` に直書きすると、そのままGitに
コミットされて漏洩します。Composeは同じディレクトリの `.env` ファイルを自動的に読み込み、
`${VARIABLE}` 構文で参照できます。`.env` 自体はGitignoreし、`.env.example`(値を含まない
テンプレート)だけをコミットするのが定石です。**値を必須にしたい変数は
`${VAR:?エラーメッセージ}` で未設定時に明示的に失敗させる**と、「パスワード未設定のまま
空文字でRedisが起動してしまう」ような事故を防げます。

### 手を動かす

`docker-compose.yml` を編集し、Redisにパスワードを設定してenvironment経由でwebに渡します。

```diff
 services:
   redis:
     image: redis:7-alpine
+    command: ["redis-server", "--requirepass", "${REDIS_PASSWORD:?REDIS_PASSWORD is not set}"]
     healthcheck:
-      test: ["CMD", "redis-cli", "ping"]
+      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
       interval: 5s
       timeout: 3s
       retries: 5
       start_period: 5s
 
   web:
     build:
       context: ../app
       dockerfile: ../solutions/01-dockerfile-quality/Dockerfile
+      args:
+        APP_VERSION: ${APP_VERSION:-dev}
     environment:
       REDIS_HOST: redis
+      REDIS_PASSWORD: ${REDIS_PASSWORD:?REDIS_PASSWORD is not set}
+      APP_VERSION: ${APP_VERSION:-dev}
     ports:
       - "8000:8000"
     depends_on:
       redis:
         condition: service_healthy
```

`redis-commander` の `REDIS_HOSTS` にもパスワードを渡すよう更新します(`redis-commander`
サービス定義の `REDIS_HOSTS` を `local:redis:6379:0:${REDIS_PASSWORD}` に変更)。

`.env.example` を新規作成します(**これはコミットする**テンプレートです)。

```
REDIS_PASSWORD=change_me_locally
APP_VERSION=dev
```

そして `.env`(**これはコミットしない**実値)をローカルに作ります。

```bash
cp .env.example .env
# 好きなパスワードに書き換える(このハンズオンではローカル用の適当な値でOK)
```

`../.gitignore` に `**/.env`(`.env.example` は除外)を設定済みなので、`.env` が誤って
コミットされないことを確認しておきましょう。

```bash
cd ..
git check-ignore -v 02-compose-practices/.env
# => .gitignore:2:**/.env  02-compose-practices/.env  のように、無視されている行が表示されればOK
cd 02-compose-practices
```

### 動作確認

```bash
# .envなしで動かないことを確認(機密情報必須のフェイルファストが機能しているか)
mv .env .env.bak
docker compose up -d
# => "REDIS_PASSWORD is not set" のようなエラーで起動が失敗するはず
mv .env.bak .env

# .envありで正常に起動することを確認
docker compose up -d --build
curl -s http://localhost:8000/health
docker compose exec redis redis-cli -a "$(grep REDIS_PASSWORD .env | cut -d= -f2)" ping
# => PONG

docker compose down -v
```

完成形は `../solutions/02-compose-practices/` にも置いてあります
(`docker-compose.yml` / `docker-compose.override.yml` / `docker-compose.prod.yml` / `.env.example`)。
詰まったら見比べてください。

---

## 理解度確認

1. `depends_on` に `condition: service_healthy` を指定しない場合、実務でどのような
   不安定さにつながりますか?このハンズオンで使ったRedisを例に説明してください。
2. `profiles` を使わずに全サービスを常時起動する構成にすると、どんなデメリットがありますか?
3. `docker-compose.override.yml` と `docker-compose.prod.yml` の、Composeによる
   読み込まれ方の違いを説明してください。
4. `.env` ファイルをコミットせず `.env.example` だけをコミットするのはなぜですか?
   また `${REDIS_PASSWORD:?...}` のような書き方にはどんな効果がありますか?
5. 本番相当の設定で起動する際、実際にどのコマンドを打つべきか答えてください。

<details>
<summary>解答例(クリックで表示)</summary>

1. Redisコンテナのプロセスが起動した直後、実際に接続を受け付けられる状態になる前にwebが
   接続を試み、起動直後だけ間欠的に接続エラーが発生する可能性がある。特に初期化に時間の
   かかるDB(MySQL/Postgresなど)では顕著。
2. 常に全部起動しているとリソースを無駄に消費し、起動時間も伸びる。デバッグ用ツールが
   本番相当の検証環境にも誤って含まれてしまうリスクもある。
3. `docker-compose.override.yml` は `docker compose up` 実行時に自動的にベースファイルへ
   合成される。`docker-compose.prod.yml` のようなそれ以外の名前のファイルは、`-f` で
   明示的に指定しない限り読み込まれない。
4. `.env` には実際のパスワードなどの機密値が入るため、コミットするとリポジトリ経由で
   漏洩する。`.env.example` は「どんな変数が必要か」というテンプレートだけを共有するために
   コミットする。`${VAR:?message}` は変数が未設定(または空)の場合にComposeがエラーで
   停止するようにする書き方で、パスワード未設定のまま空文字で起動してしまう事故を防げる。
5. `docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d`
   (`docker-compose.override.yml` は自動合成されないよう、明示的にファイルを指定する)

</details>

次は [`03-debug-ops/README.md`](../03-debug-ops/README.md) に進んでください。
