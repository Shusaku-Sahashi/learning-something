# Docker 実務レベル・ハンズオン教材

Dockerの基本コマンドとDockerfile/docker-compose.ymlの基本構文を理解している人が、
「実務で通用するレベル」に引き上げるための、手を動かす形式の教材です。

座学パートは最小限にとどめ、各トピックで「壊れた/未熟な状態」から始めて自分の手で
改善していく構成にしています。

## 前提環境

- Docker Desktop または Docker Engine (24.x以降推奨。`docker buildx version` が通ること)
- Docker Compose v2 (`docker compose version` で確認。`docker-compose` ではなく `docker compose` を使います)
- ターミナル操作の基本

```bash
docker version
docker compose version
docker buildx version
```

## 共通で使うサンプルアプリ

`app/` に、全トピックを通して使い回す小さなFlask + Redisのアプリを置いています。

- `GET /` : Redisのカウンターをインクリメントして返す(依存サービスとの疎通確認に使う)
- `GET /health` : Redisへの `PING` が通るかを確認するヘルスチェック用エンドポイント
- `GET /slow` : 3秒スリープするだけのエンドポイント(`docker stats` / `logs --since` の練習用)

`app/Dockerfile` は**意図的に実務未満の書き方**にしてあります。これを
`01-dockerfile-quality/` の手順で段階的に改善していくのが最初のハンズオンです。

## 進め方

1. [`01-dockerfile-quality/`](./01-dockerfile-quality/README.md) — Dockerfileの質向上
2. [`02-compose-practices/`](./02-compose-practices/README.md) — Docker Composeの実践的な機能
3. [`03-debug-ops/`](./03-debug-ops/README.md) — デバッグ・運用コマンド
4. [`04-build-distribution/`](./04-build-distribution/README.md) — ビルド・配布(buildx / タグ戦略)
5. [`05-security-lite/`](./05-security-lite/README.md) — 軽めのセキュリティ(脆弱性スキャン / ベースイメージ比較)

番号順に進める前提で設計しています。02以降は前のトピックの成果物(改善したDockerfile等)を
使い回します。もし自分で改善しきれなかった場合は `solutions/` 以下に各トピックの完成形を
置いているので、そこからコピーして先に進んでください(答え合わせにも使えます)。

```
docker-hands-on/
├── app/                        # 共通サンプルアプリ(段階的に改善していく対象)
├── 01-dockerfile-quality/      # Dockerfile改善ハンズオン
├── 02-compose-practices/       # Compose実践ハンズオン
├── 03-debug-ops/               # デバッグ・運用コマンド
├── 04-build-distribution/      # buildx / タグ戦略
├── 05-security-lite/           # スキャン / ベースイメージ比較
└── solutions/                  # 各トピックの完成形(答え合わせ用)
```

## 後片付け

ハンズオン中に作ったコンテナ・イメージ・ボリュームは、都度以下でクリーンにできます。

```bash
docker compose down -v
docker image prune -f
```

それでは [`01-dockerfile-quality/README.md`](./01-dockerfile-quality/README.md) から始めましょう。
