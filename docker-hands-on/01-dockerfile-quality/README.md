# 01. Dockerfileの質向上

対象ファイル: `../app/Dockerfile`(このファイルを直接編集していきます)

現状のDockerfileを確認してください。

```dockerfile
FROM python:3.12
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
ENV REDIS_HOST=redis
EXPOSE 8000
CMD ["python", "app.py"]
```

動きはしますが、次の5点で実務レベルに達していません。1つずつ改善していきます。
各ステップの最後に `docker build` と `docker run` で必ず動作確認してください。

まず動くことを確認しておきましょう。

```bash
cd docker-hands-on
docker build -t app:naive ./app
docker images app:naive --format "{{.Size}}"
```

サイズをメモしておいてください(python:3.12フルイメージなので 900MB〜1GB程度になるはずです)。
これを本ハンズオンの終わりでどこまで削れるか、最後に見比べます。

---

## Step 1: 非rootユーザーで実行する(USER命令)

### なぜ重要か

デフォルトのDockerコンテナはrootユーザーで動きます。コンテナ内でrootのまま任意コード実行(RCE)の
脆弱性を突かれると、コンテナエスケープやホストのマウント領域改ざんのリスクが上がります。
実務では「コンテナがrootで動いている」こと自体がセキュリティレビューで指摘される定番項目です。
Kubernetesの `runAsNonRoot: true` のようなPodSecurity設定と組み合わせて使われることも多く、
「イメージ側が非rootに対応していない」と本番のSecurityContext設定でコンテナが起動しない、
という事故もよく起きます。

### 手を動かす

`app/Dockerfile` に非rootユーザーを追加します。

```diff
 FROM python:3.12
 WORKDIR /app
 COPY . .
 RUN pip install -r requirements.txt
 ENV REDIS_HOST=redis
+
+RUN groupadd --gid 1000 appuser \
+    && useradd --uid 1000 --gid appuser --create-home appuser \
+    && chown -R appuser:appuser /app
+
+USER appuser
+
 EXPOSE 8000
 CMD ["python", "app.py"]
```

### 動作確認

```bash
docker build -t app:step1-user ./app
docker run --rm app:step1-user id
# uid=1000(appuser) gid=1000(appuser) と表示されればOK(uid=0=rootではないこと)
```

`whoami` や `id` がrootでないことに加えて、`app` ディレクトリの所有者もappuserになっている
必要があります(そうでないとPythonがファイルを書き込む処理で権限エラーになります)。

```bash
docker run --rm app:step1-user ls -ld /app
```

---

## Step 2: .dockerignoreの活用

### なぜ重要か

`COPY . .` はビルドコンテキスト全体をDockerデーモンに送信してからコピーします。
`.git/`、`__pycache__/`、ローカルの `.env`、`node_modules/` などが紛れ込むと、

- ビルドコンテキストが肥大化してビルドが遅くなる
- 開発者のローカル専用ファイル(`.env` の実値など)が**イメージに焼き込まれて流出する**
- キャッシュが余計なファイル変更で無効化され、ビルドキャッシュの恩恵が薄れる

といった問題が起きます。特に「`.env` をコンテナに埋め込んでしまい、レジストリ経由で
機密情報が漏れる」は実務で実際によく起きる事故です。

### 手を動かす

まず汚れたビルドコンテキストを再現します。

```bash
cd app
mkdir -p __pycache__
echo "dummy" > __pycache__/app.cpython-312.pyc
echo "SECRET_KEY=super-secret-local-value" > .env
cd ..
```

`.dockerignore` がない状態でこれらがイメージに入ってしまうことを確認します。

```bash
docker build -t app:dirty ./app
docker run --rm app:dirty ls -la /app
docker run --rm app:dirty cat /app/.env
# ローカル専用の .env の中身がそのままコンテナから読めてしまう
```

`app/.dockerignore` を新規作成します。

```dockerignore
.git
.gitignore
__pycache__/
*.pyc
.venv/
venv/
.env
.env.*
!.env.example
Dockerfile
docker-compose*.yml
README.md
```

### 動作確認

```bash
docker build -t app:step2-ignore ./app
docker run --rm app:step2-ignore ls -la /app
docker run --rm app:step2-ignore cat /app/.env
# => "cat: /app/.env: No such file or directory" になればOK(.envがイメージに含まれていない)
```

後片付け:

```bash
rm -rf app/__pycache__ app/.env
```

---

## Step 3: HEALTHCHECK命令

### なぜ重要か

`docker ps` の `STATUS` は「プロセスが起動しているか」しか見ません。アプリのプロセス自体は
生きていても、DB接続が切れて全リクエストが500を返す「生きているが死んでいる」状態はよくあります。
`HEALTHCHECK` を定義すると `docker ps` の `STATUS` に `(healthy)` / `(unhealthy)` が出るようになり、
さらに後述の `depends_on: condition: service_healthy`(Compose)や、オーケストレータの
自動再起動・ロードバランサからの除外判定にも使われます。これを入れていないと、
「デプロイは成功と表示されているのに実際は502を返し続けている」事故につながります。

### 手を動かす

```diff
 USER appuser
 
+HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
+  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1
+
 EXPOSE 8000
 CMD ["python", "app.py"]
```

`curl` を使わず標準ライブラリの `urllib` を使っている点がポイントです。ヘルスチェック用に
`curl` を追加インストールすると、その分イメージサイズと攻撃対象領域(attack surface)が
増えてしまいます。slim系イメージには元々curlが入っていないことが多いので、
言語のランタイムに標準で入っているものを使うのが実務でもよくあるパターンです。

### 動作確認

Redisがないと `/health` は失敗するので、一時的にRedisも起動して確認します。

```bash
docker network create hc-test 2>/dev/null || true
docker run -d --name hc-redis --network hc-test redis:7-alpine
docker build -t app:step3-healthcheck ./app
docker run -d --name hc-app --network hc-test \
  -e REDIS_HOST=hc-redis -p 8000:8000 app:step3-healthcheck

# 数秒待ってから確認
sleep 12
docker ps --filter "name=hc-app" --format "{{.Names}}: {{.Status}}"
# => "hc-app: Up ... (healthy)" と表示されればOK
```

わざとRedisを止めて `unhealthy` に遷移することも確認しておくと理解が深まります。

```bash
docker stop hc-redis
sleep 40
docker ps --filter "name=hc-app" --format "{{.Names}}: {{.Status}}"
# => "(unhealthy)" に変わるはず
```

後片付け:

```bash
docker rm -f hc-app hc-redis
docker network rm hc-test
```

---

## Step 4: ARGとENVの使い分け

### なぜ重要か

`ARG` は**ビルド時のみ**有効な変数、`ENV` は**イメージに焼き込まれ実行時にも残る**変数です。
この違いを理解せずに使うと、

- ビルド時にしか使わないバージョン番号などをうっかり `ENV` にして、実行時の環境変数
  一覧を無駄に汚す
- 逆に実行時に変えたい設定(接続先ホストなど)を `ARG` にしてしまい、イメージをリビルド
  しないと値を変更できない(本来はコンテナ起動時の `-e` やComposeの `environment` で
  変更できるべき)
- **秘密情報を `ARG` に渡すと、`docker history` でビルド時の値がそのまま見えてしまう**
  (レイヤーに残るため。本当の秘密情報はビルド時もBuildKitの `--secret` を使うべきで、
  `ARG`/`ENV` に生の秘密情報を渡してはいけない、というのもここで押さえておきたい教訓です)

という事故につながります。「ビルド時に決まって実行時は変わらない値はARG」「実行時に
変えたい/変えられるべき値はENV(またはComposeのenvironmentで注入)」という使い分けが基本です。

### 手を動かす

Pythonのバージョンをビルド時に切り替えられるようにしつつ、アプリのバージョン表示は
ビルド時に注入しつつ実行時にも参照できるようにします。

```diff
-FROM python:3.12
+ARG PYTHON_VERSION=3.12
+FROM python:${PYTHON_VERSION}
+
+ARG APP_VERSION=dev
+ENV APP_VERSION=${APP_VERSION} \
+    REDIS_HOST=redis
+
 WORKDIR /app
 COPY . .
 RUN pip install -r requirements.txt
-ENV REDIS_HOST=redis
 
 RUN groupadd --gid 1000 appuser \
     && useradd --uid 1000 --gid appuser --create-home appuser \
     && chown -R appuser:appuser /app
```

ポイント:
- `PYTHON_VERSION` は「どのベースイメージを使ってビルドするか」というビルド時だけの関心事なので `ARG`
- `APP_VERSION` は「このイメージが何のバージョンか」を実行時にアプリ自身が返せるようにしたいので、
  `ARG` で受け取った値を `ENV` に代入して実行時にも残す、という組み合わせ技を使う

### 動作確認

```bash
docker build --build-arg APP_VERSION=1.2.3 -t app:step4-argenv ./app
docker run --rm app:step4-argenv python -c "import os; print(os.environ['APP_VERSION'])"
# => 1.2.3

# ビルド時の値がイメージ履歴に残っていることも確認(ARGが実行時に残らないこと自体は
# printenvで確認できますが、ここではAPP_VERSIONがENV経由で正しく実行時にも見えることを確認します)
docker run --rm -e APP_VERSION=override-at-runtime app:step4-argenv \
  python -c "import os; print(os.environ['APP_VERSION'])"
# => override-at-runtime (ENVはデフォルト値であり、実行時の -e で上書きできることも確認)
```

`PYTHON_VERSION` を変えてビルドできることも確認します。

```bash
docker build --build-arg PYTHON_VERSION=3.11 -t app:step4-py311 ./app
docker run --rm app:step4-py311 python --version
# => Python 3.11.x
```

---

## Step 5: マルチステージビルドによるイメージサイズ削減

### なぜ重要か

現状のDockerfileは `python:3.12`(フルイメージ、900MB超)をそのまま本番イメージとして使っています。
実務では以下が問題になります。

- イメージが大きいほどpull/デプロイに時間がかかり、ロールアウト・オートスケールが遅くなる
- ビルドに必要なツール(コンパイラ等)が本番イメージにそのまま残り、攻撃対象領域が増える
- レジストリのストレージ・転送コストが増える

マルチステージビルドで「依存関係をインストールするステージ」と「実行するステージ」を分け、
実行ステージには軽量な `-slim` ベースイメージ+実行に必要な成果物だけを持ち込みます。

### 手を動かす

これまでの改善を踏まえた最終形です。

```dockerfile
# syntax=docker/dockerfile:1
ARG PYTHON_VERSION=3.12

FROM python:${PYTHON_VERSION}-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

FROM python:${PYTHON_VERSION}-slim AS runtime
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION} \
    REDIS_HOST=redis \
    REDIS_PORT=6379 \
    PATH=/home/appuser/.local/bin:$PATH \
    PYTHONUNBUFFERED=1

RUN groupadd --gid 1000 appuser \
    && useradd --uid 1000 --gid appuser --create-home appuser

WORKDIR /app
COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local
COPY --chown=appuser:appuser . .

USER appuser

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

EXPOSE 8000
CMD ["python", "app.py"]
```

`builder` ステージで `pip install --user` を使い、`/root/.local` に依存パッケージだけを
インストールしている点がポイントです。`runtime` ステージにはpipのキャッシュもビルドツールも
コピーされず、実行に必要なファイルだけが渡ります。

`.dockerignore` に `Dockerfile` や `docker-compose*.yml` を含めているので、
`COPY --chown=appuser:appuser . .` でアプリの不要ファイルが紛れ込まないことも
このステップで再確認しておいてください。

### 動作確認

```bash
docker build --build-arg APP_VERSION=1.0.0 -t app:final ./app

# サイズ比較(このハンズオンの最初にメモしたapp:naiveのサイズと比較する)
docker images app --format "{{.Repository}}:{{.Tag}}\t{{.Size}}"
```

`python:3.12`(素のイメージ)から `python:3.12-slim` ベースのマルチステージに変えることで、
概ね半分以下、場合によっては1/3程度までサイズが減ることを確認してください。

最後に、これまでの全ステップが組み合わさって正しく動くことを、Redisと繋いで確認します。

```bash
docker network create final-test 2>/dev/null || true
docker run -d --name final-redis --network final-test redis:7-alpine
docker run -d --name final-app --network final-test \
  -e REDIS_HOST=final-redis -p 8000:8000 app:final

sleep 12
curl -s http://localhost:8000/ | python3 -m json.tool
docker ps --filter name=final-app --format "{{.Names}}: {{.Status}}"
docker exec final-app id   # rootでないこと

docker rm -f final-app final-redis
docker network rm final-test
```

完成形は `../solutions/01-dockerfile-quality/Dockerfile` と
`../solutions/01-dockerfile-quality/.dockerignore` にも置いてあります。詰まったら見比べてください。

---

## 理解度確認

1. `USER` 命令を入れずにコンテナをrootで動かし続けると、実務上どんなリスクが具体的に増えるか、
   1つ具体例を挙げて説明してください。
2. `.dockerignore` を書かずに `COPY . .` した場合、どのような情報がイメージに混入しうるか、
   このハンズオンで実際に確認した例を挙げてください。
3. `HEALTHCHECK` が定義されていないコンテナでは、`docker ps` のSTATUS表示だけでは
   どのような障害を見逃す可能性がありますか?
4. 次の2つの変数はそれぞれ `ARG` と `ENV` のどちらで定義すべきか、理由も含めて答えてください。
   - a. アプリが接続するデータベースのホスト名(実行時にComposeやK8sから注入したい)
   - b. ビルド時にどのバージョンのベースイメージを使うか選択するための変数
5. マルチステージビルドを使わずに `python:3.12`(非slim)でビルド・依存インストールした
   イメージをそのまま本番稼働させると、具体的にどのようなコストが増えますか?2つ挙げてください。

<details>
<summary>解答例(クリックで表示)</summary>

1. コンテナ内でRCE系の脆弱性を突かれた場合、rootだとコンテナ内で任意のパッケージ導入・
   設定ファイル改ざんが容易になり、さらにコンテナブレイクアウト系の脆弱性と組み合わさると
   ホスト側にも影響が及ぶリスクが上がる。KubernetesのSecurityContextで`runAsNonRoot: true`
   を強制している環境では、非root対応していないイメージはそもそも起動できない。
2. `.git`、`__pycache__`、ローカルの`.env`(このハンズオンでは `SECRET_KEY` を含む `.env`)
   などが混入しうる。特にローカル専用の秘密情報がイメージに焼き込まれ、レジストリ経由で
   外部に漏れるリスクがある。
3. アプリプロセス自体は起動しているが、DB接続断などでリクエストに正常応答できない
   「生きているが壊れている」状態を見逃す。オーケストレータの自動復旧やLBからの除外判定にも
   使われるため、これが無いと壊れたコンテナにトラフィックが送られ続ける。
4. a. `ENV`(またはComposeの`environment`で注入)。実行環境ごとに変わる値であり、
      イメージをリビルドせずに切り替えられるべきだから。
   b. `ARG`。ビルド時にのみ意味を持つ値で、実行時のコンテナには不要だから。
5. イメージサイズの増大によるpull/デプロイ時間の増加、ビルドツールやライブラリが残ることに
   よる攻撃対象領域(脆弱性の混入経路)の増加。レジストリのストレージ・転送コスト増も該当する。

</details>

次は [`02-compose-practices/README.md`](../02-compose-practices/README.md) に進んでください。
