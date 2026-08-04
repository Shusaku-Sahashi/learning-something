# 03. デバッグ・運用コマンド

02で作った(または `solutions/02-compose-practices/` の)Composeスタックを使って、
「動いているコンテナに対して」実務でよく使う調査・運用系コマンドを体に馴染ませます。

まずスタックを起動します。

```bash
cd docker-hands-on/solutions/02-compose-practices
cp -n .env.example .env
docker compose up -d --build
docker compose ps
```

---

## Step 1: `docker exec` と `docker attach` の違いを体感する

### なぜ重要か

この2つを混同すると事故ります。`docker attach` は**コンテナのメインプロセス(PID 1)の
標準入出力にそのまま接続**します。ここで `Ctrl+C` を押すと、ターミナルから切り離されるの
ではなく**メインプロセスにSIGINTが送られてコンテナ自体が停止する**ことがあります
(実務で「ちょっとログを見ようとattachしてCtrl+Cしたら本番コンテナが落ちた」という
事故が実際に起きます)。一方 `docker exec` は**新しいプロセスをコンテナ内に追加で起動**
するので、そこで何をしてもメインプロセスには影響しません。調査目的でコンテナに入る時は
基本的に `exec` を使うべきで、`attach` はメインプロセスの標準出力に直接張り付きたい
特殊なケース(かつ切断方法を理解している場合)に限定すべきです。

### 手を動かす

まず `exec` で安全にコンテナに入ります。

```bash
docker compose exec web sh
# コンテナ内でid, ps, envなどを試してから
exit
```

`exec` はプロセスが増えるだけなのを `docker top` で確認します。

```bash
docker compose exec web sleep 30 &
docker top $(docker compose ps -q web)
# execで追加されたプロセスがメインプロセスとは別に増えていることを確認
wait
```

次に `attach` の挙動を確認します。**ここではCtrl+Cを押さず、`docker attach --detach-keys`
用のキーで安全に離脱する方法を練習します。**

```bash
docker attach --detach-keys="ctrl-p,ctrl-q" $(docker compose ps -q web)
```

この状態でアプリのログがそのまま流れ込んでくるのを確認したら、`Ctrl+C` ではなく
**`Ctrl+P` に続けて `Ctrl+Q`** を押してデタッチしてください。コンテナを落とさずに
ターミナルから抜けられます。

```bash
docker compose ps
# webがまだRunningのままであることを確認
```

比較として(**必ず使い捨て用に別途起動した検証用コンテナで**)、`attach` 中に `Ctrl+C`
を押すとメインプロセスが終了してコンテナが停止することも確認しておくと理解が深まります。

```bash
docker run -d --name attach-test alpine sh -c "trap 'echo caught SIGINT; exit 1' INT; while true; do sleep 1; done"
docker attach attach-test
# ここでCtrl+Cを押す
docker ps -a --filter name=attach-test --format "{{.Names}}: {{.Status}}"
# => Exited と表示され、コンテナが停止していることを確認
docker rm -f attach-test
```

### 動作確認

- `exec` でコンテナに入って抜けても、コンテナのステータスが変わらないこと
- `attach` から `Ctrl+P, Ctrl+Q` でデタッチしてもコンテナが動き続けること
- `attach` 中に `Ctrl+C` を送るとコンテナのメインプロセスが終了しうること

の3点を自分の手で確認できていればOKです。

---

## Step 2: `docker stats` / `docker logs --since`

### なぜ重要か

障害調査で最初にやることは大抵「リソースを食っているコンテナの特定」と「直近のログ確認」です。
`docker stats` はリアルタイムのCPU/メモリ/ネットワークI/Oを一覧できます。`docker logs`
はデフォルトで全ログを出しますが、稼働の長いコンテナでは全ログを見るのは非現実的なので、
`--since` / `--until` で時間範囲を絞り込むのが実務での基本です。

### 手を動かす

`/slow` エンドポイントに負荷をかけつつリソースを観察します。

```bash
for i in $(seq 1 20); do curl -s http://localhost:8000/slow > /dev/null & done

docker stats --no-stream
# 一覧のスナップショットが取れる。負荷をかけている間にCPU%が上がるのを確認
```

継続的に監視したい場合は `--no-stream` を外して数秒観察してから `Ctrl+C` で抜けます。

```bash
docker stats
```

ログを時間で絞り込みます。

```bash
# 直近5分のログだけ
docker compose logs --since 5m web

# 特定の時刻以降(ISO8601)
docker compose logs --since "$(date -u -d '2 minutes ago' +%Y-%m-%dT%H:%M:%S)" web

# 追いかけつつ直近1分だけ表示
docker compose logs -f --since 1m web
```

### 動作確認

- `docker stats --no-stream` の出力に `web` と `redis` のCPU%・MEM USAGE列が表示されること
- `docker compose logs --since 5m web` の出力が、`docker compose logs web`(全件)より
  短いか同じ範囲であること(コンテナ起動から5分以上経っていれば行数が減っているはず)

---

## Step 3: `docker system df` / `docker system prune`

### なぜ重要か

開発を続けているとイメージ・コンテナ・ボリューム・ビルドキャッシュがディスクを圧迫します。
CI環境でも「ビルドのたびにディスクが埋まってジョブが失敗する」事故は定番です。
`docker system df` で「何にどれだけ使われているか」を可視化してから、**闇雲に `prune`
しない**のが実務での鉄則です。特に `docker system prune -a` はタグ付けされていない
イメージだけでなく、使われていない全イメージを消すため、他のプロジェクトで参照している
イメージまで巻き込んで消してしまうことがあります。

### 手を動かす

まず現状を可視化します。

```bash
docker system df
docker system df -v | head -40
```

不要なリソースがどれだけあるか確認してから、範囲を絞って掃除します。

```bash
# 停止中コンテナだけ確認(消す前に必ず一覧を見る)
docker container ls -a --filter status=exited

# ダングリングイメージ(タグなしイメージ)だけ確認してから削除
docker image ls --filter dangling=true
docker image prune -f

# 最後に全体のprune(コンテナ・ネットワーク・ダングリングイメージ・ビルドキャッシュ)
# -a を付けない限り、未使用の"タグ付き"イメージまでは消えない
docker system prune -f
```

### 動作確認

`docker system prune -f` の前後で `docker system df` の出力を比較し、
`RECLAIMABLE` の量が実行後に減っていることを確認してください。

```bash
docker system df
docker system prune -f
docker system df
```

---

## Step 4: `docker inspect` での詳細調査

### なぜ重要か

「なぜこのコンテナはこのIPなのか」「実際に適用されている環境変数は何か」「マウントは
正しいホストパスに向いているか」「ヘルスチェックの直近の結果は何だったか」——
これらはコンテナの外からは見えず、`docker inspect` で構造化データとして取得できます。
`--format` (Goテンプレート) と組み合わせると、必要な情報だけをスクリプトで抜き出せるように
なり、障害調査の自動化やアラート連携の基礎になります。

### 手を動かす

```bash
# フルダンプ(まずは全体像を眺める)
docker inspect $(docker compose ps -q web) | less

# 特定フィールドだけ抜き出す
docker inspect --format '{{.State.Health.Status}}' $(docker compose ps -q web)
docker inspect --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' $(docker compose ps -q web)
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' $(docker compose ps -q web)
docker inspect --format '{{.NetworkSettings.Networks}}' $(docker compose ps -q web)
```

直近のヘルスチェック実行ログ(成功/失敗の履歴)も見られます。

```bash
docker inspect --format '{{json .State.Health.Log}}' $(docker compose ps -q web) | python3 -m json.tool
```

### 動作確認

- `--format '{{.State.Health.Status}}'` で `healthy` が返ること
- `--format` でMountsを見た際、`docker-compose.override.yml` でbind mountした
  `../app -> /app` が表示されること(02のStep3を完了している場合)
- `Health.Log` に直近数回分のヘルスチェック結果(`ExitCode: 0`)が並んでいること

後片付け:

```bash
docker compose down -v
```

---

## 理解度確認

1. `docker attach` 中に `Ctrl+C` を押すと何が起きる可能性がありますか?安全にデタッチする
   ためのキー操作は何ですか?
2. 障害調査で「まずリソース状況を見る」「まずログを見る」場合、それぞれどのコマンドを使いますか?
3. `docker system prune -a` を安易に実行してはいけない理由を説明してください。
4. `docker inspect` で、あるコンテナのヘルスチェックの直近の実行結果を確認するには
   どうすればよいですか?

<details>
<summary>解答例(クリックで表示)</summary>

1. `attach` はメインプロセス(PID 1)の標準入出力に直接つながるため、`Ctrl+C` を押すと
   SIGINTがそのままメインプロセスに送られ、コンテナが停止する可能性がある。安全にデタッチ
   するには `--detach-keys` で指定したキー(デフォルトは `Ctrl+P, Ctrl+Q`)を使う。
2. リソース状況の確認は `docker stats`、ログの確認は `docker logs`(必要に応じて
   `--since`/`--until` で絞り込む)。
3. `-a` を付けると、タグ付けされていて現在は使われていないイメージまで含めて全て削除
   されるため、他のプロジェクトや過去のリリースで参照しているイメージまで巻き込んで
   消してしまう危険がある。実行前に `docker system df` で影響範囲を確認すべき。
4. `docker inspect --format '{{json .State.Health.Log}}' <container>` で、直近の
   ヘルスチェック実行結果(開始時刻・終了コード・出力)の履歴を確認できる。

</details>

次は [`04-build-distribution/README.md`](../04-build-distribution/README.md) に進んでください。
