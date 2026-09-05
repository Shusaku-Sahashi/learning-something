# 05. 軽めのセキュリティ

これまでのステップで作った3つのイメージ

- `app:naive` (`../app/Dockerfile` の初期状態相当。フルサイズの `python:3.12`)
- 01の完成形 (`../solutions/01-dockerfile-quality/Dockerfile`。`-slim` + マルチステージ)
- distroless版 (`../solutions/05-security-lite/Dockerfile.distroless`。今回新規に用意)

を比較しながら、脆弱性スキャンとベースイメージ選定を体験します。

---

## Step 1: `trivy` での脆弱性スキャン

### なぜ重要か

ベースイメージにはOSパッケージが多数含まれており、そのすべてが既知の脆弱性(CVE)
データベースの対象になります。「ビルドが通ればOK」で本番投入すると、実は使ってもいない
パッケージのCVEを大量に抱えたまま公開してしまう、ということが実務では頻繁に起きます。
特に `CRITICAL`/`HIGH` の脆弱性を含むイメージをそのまま本番に出してしまい、後から
セキュリティ監査やSBOM提出の場面で指摘される、というのはよくある失敗パターンです。
`trivy` はコンテナイメージ・OSパッケージ・言語ライブラリの既知脆弱性を横断的にスキャン
できるOSSツールで、CIに組み込んで「CRITICALが出たらビルドを失敗させる」というゲートを
作るのが実務での標準的な使い方です。

### 手を動かす

trivy自体をローカルにインストールせず、コンテナとして実行します(Dockerさえあれば
すぐに試せるのが利点です)。

```bash
cd docker-hands-on

# 比較対象のイメージをビルドしておく
docker build -t app:naive ./app
docker build -t app:hardened -f ./solutions/01-dockerfile-quality/Dockerfile ./app

# trivyのDBキャッシュ用ボリュームを用意しておくと2回目以降が速い
docker volume create trivy-cache

docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v trivy-cache:/root/.cache/ \
  aquasec/trivy:latest image --severity CRITICAL,HIGH app:naive
```

同じスキャンを改善後のイメージにも実行し、結果を比較します。

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v trivy-cache:/root/.cache/ \
  aquasec/trivy:latest image --severity CRITICAL,HIGH app:hardened
```

(Docker Desktopを使っている場合は `docker scout cves app:naive` /
`docker scout cves app:hardened` でも同様の比較ができます。`docker scout quickview`
はサマリだけを手早く見たい時に便利です。)

### 動作確認

出力末尾のサマリ(`Total: N (CRITICAL: X, HIGH: Y)`)を比較し、`app:naive`
(フルサイズの`python:3.12`、OSパッケージが多い)より `app:hardened`
(`-slim`ベース)のほうが検出件数が少ないことを確認してください。

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache/ \
  aquasec/trivy:latest image --severity CRITICAL,HIGH --format json app:naive \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(sum(len(r.get('Vulnerabilities') or []) for r in d.get('Results', [])))"

docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache/ \
  aquasec/trivy:latest image --severity CRITICAL,HIGH --format json app:hardened \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(sum(len(r.get('Vulnerabilities') or []) for r in d.get('Results', [])))"
```

2つ目の件数のほうが少ない(多くの場合0件に近い)ことが確認できればOKです。

---

## Step 2: alpine/distrolessベースイメージへの置き換え比較

### なぜ重要か

`-slim` からさらに一歩進めて、`alpine`(パッケージマネージャこそあるが最小限のOS)や
`distroless`(シェルすら存在せず、アプリの実行に必要な最小限のランタイムのみ)に
置き換えると、攻撃対象領域(スキャン対象になるパッケージ数そのもの)をさらに減らせます。
ただしこれはトレードオフでもあります。distrolessには **シェルが無いので `docker exec sh`
で中に入って調査する、といった従来のデバッグ手法が使えなくなります**。実務では
「攻撃対象領域を最小化するメリット」と「運用時の調査のしやすさ」を天秤にかけて選定します。

### 手を動かす

`../solutions/05-security-lite/Dockerfile.distroless` を確認してください。
`-slim` 版との主な違いは以下です。

```diff
-FROM python:${PYTHON_VERSION}-slim AS runtime
-...
-RUN groupadd --gid 1000 appuser \
-    && useradd --uid 1000 --gid appuser --create-home appuser
-...
-COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local
-COPY --chown=appuser:appuser . .
-USER appuser
-HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
-  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1
+FROM gcr.io/distroless/python3-debian12:nonroot AS runtime
+...
+# groupadd/useraddが実行できない(シェルもパッケージマネージャも無い)ため、
+# あらかじめ非rootユーザーが組み込まれている :nonroot タグを使う
+COPY --from=builder /app/deps /app/deps
+COPY app.py .
+# HEALTHCHECKのCMDにはシェル経由のコマンドが必要だが、distrolessにはシェルが無いため
+# 従来通りのHEALTHCHECKは書けない(運用上はオーケストレータのプローブ機能側で代替する)
```

ビルドしてサイズを比較します。

```bash
docker build --build-arg APP_VERSION=1.0.0 \
  -t app:distroless \
  -f ./solutions/05-security-lite/Dockerfile.distroless \
  ./app

docker images app --format "{{.Tag}}\t{{.Size}}"
```

`app:naive` → `app:hardened` → `app:distroless` の順にサイズが小さくなっていくことを
確認してください。

脆弱性スキャンも実行して比較します。

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache/ \
  aquasec/trivy:latest image --severity CRITICAL,HIGH app:distroless
```

### 動作確認

実際に動かして機能面で問題がないかも確認します。

```bash
docker network create distroless-test 2>/dev/null || true
docker run -d --name dl-redis --network distroless-test redis:7-alpine
docker run -d --name dl-app --network distroless-test \
  -e REDIS_HOST=dl-redis -p 8001:8000 app:distroless

sleep 3
curl -s http://localhost:8001/ | python3 -m json.tool
```

distrolessにはシェルが無いため、`docker exec dl-app sh` が**使えないこと**も
実際に確認しておきましょう(これがトレードオフの実感です)。

```bash
docker exec -it dl-app sh
# => "OCI runtime exec failed: exec failed: unable to start container process: exec: \"sh\": executable file not found in $PATH" のようなエラーになる
```

調査したい場合は、同じイメージの `:debug` タグ(busybox入り)を一時的に使う、
という代替手段があることも押さえておいてください
(例: `gcr.io/distroless/python3-debian12:debug-nonroot`)。

後片付け:

```bash
docker rm -f dl-app dl-redis
docker network rm distroless-test
```

---

## 理解度確認

1. `trivy image` でスキャンした際に `CRITICAL`/`HIGH` の脆弱性が多数検出された場合、
   実務ではどのように対応の優先順位をつけるべきだと思いますか?(ヒント: 全部を一度に
   直そうとする必要はありません)
2. `-slim` ベースから `distroless` に置き換えることで得られるメリットと、
   引き換えに失うものをそれぞれ1つ以上挙げてください。
3. distrolessイメージには `HEALTHCHECK` をそのままの形では書けません。実務ではどのように
   ヘルスチェックの仕組みを代替すればよいですか?
4. CIパイプラインに `trivy` スキャンを組み込むとしたら、どのタイミングで・どんな条件で
   ビルドを失敗させるのが良いと思いますか?

<details>
<summary>解答例(クリックで表示)</summary>

1. まずCRITICAL、次にHIGHの順で、かつ「実際に到達可能なコードパスで使われているか」
   「修正版が存在するか」を見て優先順位をつける。全件を即座に0にすることを目指すのではなく、
   継続的にベースイメージ更新やライブラリのバージョンアップで減らしていく運用にするのが現実的。
2. メリット: シェルやパッケージマネージャ自体が存在しないため攻撃対象領域(CVEの発生源)が
   大幅に減り、イメージサイズも小さくなる。失うもの: `docker exec sh` のような従来の
   デバッグ手法が使えなくなる、HEALTHCHECKのようなシェルコマンド前提の機能が使えなくなる、
   トラブルシュートの難易度が上がる。
3. Docker単体のHEALTHCHECK(シェルコマンド実行前提)には頼らず、オーケストレータ
   (Kubernetesのliveness/readinessプローブなど)のTCPソケットチェックやHTTPプローブ
   (アプリ側がHTTPで応答しさえすればよい仕組み)を使う。調査時だけ`:debug`タグの
   イメージに一時的に切り替える、という運用もある。
4. CRITICAL(場合によってはHIGHも)が1件でも検出されたらビルド/デプロイパイプラインを
   失敗させる、という形が一般的。ただし修正版が存在しない・実際には到達しないコード
   パスの脆弱性については、レビューの上でallowlistに載せて例外扱いにする運用も
   組み合わせることが多い。

</details>

---

## おわりに

`app:naive` → `app:hardened`(01の成果物)→ `app:distroless` で、同じアプリケーションが
どれだけサイズを削減し、攻撃対象領域を減らせたかを最後に見比べてみてください。

```bash
docker images app --format "{{.Tag}}\t{{.Size}}"
```

これで5トピック全てのハンズオンが完了です。お疲れ様でした。
