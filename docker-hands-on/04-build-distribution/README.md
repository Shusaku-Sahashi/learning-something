# 04. ビルド・配布

01で作った `../solutions/01-dockerfile-quality/Dockerfile` を使い、複数アーキテクチャ向けの
ビルドと、実務で通用するタグ戦略を練習します。実際のクラウドレジストリの認証情報は
使わず、**ローカルにレジストリコンテナを立てて**そこにpushする形で体験します。

```bash
docker run -d -p 5000:5000 --restart unless-stopped --name local-registry registry:2
```

---

## Step 1: `docker buildx` によるマルチプラットフォームビルド

### なぜ重要か

Apple Silicon(arm64)開発機とx86_64本番サーバが混在する現場、あるいはAWS Graviton
(arm64)のようなコスト最適化目的のarm64本番環境が普及したことで、「開発機ではpullできて
動くのに、本番のarm64サーバでは `exec format error` で起動しない」という事故が
実際に起きます。`docker build` は**実行しているマシンのアーキテクチャ向け**のイメージしか
作りません。複数アーキテクチャに対応するには `docker buildx` で1回のビルドから
複数プラットフォーム向けのイメージをまとめて作り、**1つのタグの下にマルチアーキ
マニフェスト**として配布する必要があります。

### 手を動かす

まず現在のビルダーを確認し、マルチプラットフォームに対応したビルダーを作成します。

```bash
docker buildx ls
docker buildx create --name hands-on-builder --driver docker-container --use
docker buildx inspect --bootstrap
```

`docker-container` ドライバを使う点がポイントです。デフォルトの `docker` ドライバは
単一プラットフォームしかビルドできません。

シングルプラットフォームのビルド(今まで通り、ローカルにロードされる)を試します。

```bash
docker buildx build --platform linux/amd64 \
  -t localhost:5000/app:single-amd64 \
  --load \
  ../app -f ../solutions/01-dockerfile-quality/Dockerfile
```

次に、amd64とarm64の**両方**を1回のコマンドでビルドし、レジストリにpushします。

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -t localhost:5000/app:multi-arch-demo \
  --push \
  ../app -f ../solutions/01-dockerfile-quality/Dockerfile
```

**ここが重要な落とし穴です**: マルチプラットフォームビルドの結果は `--load` で
ローカルのDockerには読み込めません(ローカルには「1つのイメージ」という概念しかなく、
複数アーキテクチャをまとめたマニフェストを読み込む先がないため)。ローカルで確認したい
場合は `--push` でレジストリに送るか、`--platform` を1つに絞って `--load` するかの
どちらかを選ぶ必要があります。

### 動作確認

pushしたマニフェストが本当に2アーキテクチャ分を含んでいるか確認します。

```bash
docker buildx imagetools inspect localhost:5000/app:multi-arch-demo
```

出力に `linux/amd64` と `linux/arm64` の両方のエントリ(それぞれ別のdigestを持つ)が
表示されればOKです。1つのタグの下に複数プラットフォームのイメージがぶら下がっている
状態を確認できたら成功です。

```bash
docker buildx imagetools inspect localhost:5000/app:multi-arch-demo --format '{{json .Manifest}}' | python3 -m json.tool | grep -A2 platform
```

---

## Step 2: タグ戦略(`latest` に頼らない運用)

### なぜ重要か

`latest` タグだけで運用すると、次のような事故が起きます。

- 「本番で `latest` をpullし直したらいつの間にか別バージョンが動いていた」
  (`latest` は「最新にpushされたタグなし相当のイメージ」という慣習に過ぎず、
  バージョンを一切表さない。ロールバックしたくても「どれが1つ前の`latest`か」が
  イメージ名からは分からない)
- 複数人・複数CIが同時に `latest` へpushすると、意図しない上書きレースが起きる
- Kubernetesの `imagePullPolicy: IfNotPresent` と組み合わさると、ノードによって
  古い `latest` がキャッシュされたまま動き続ける、といった不整合も起きる

実務では **「デプロイした特定のイメージを、いつでも一意に指し示せる」** ことが重要です。
Gitのコミットハッシュや、SemVerに基づくバージョン番号をタグに含めるのが定石です。

### 手を動かす

Gitのコミットハッシュと、日付ベースのビルド番号を組み合わせて複数タグを同時に付けます。

```bash
cd /path/to/repo   # リポジトリのルート
GIT_SHA=$(git rev-parse --short HEAD)
BUILD_DATE=$(date -u +%Y%m%d%H%M%S)
VERSION="1.0.0"   # 実務ではリリースタグやCIの変数から取得する

cd docker-hands-on
docker buildx build --platform linux/amd64 \
  -t "localhost:5000/app:${VERSION}" \
  -t "localhost:5000/app:${VERSION}-${GIT_SHA}" \
  -t "localhost:5000/app:sha-${GIT_SHA}" \
  --load \
  ./app -f ./solutions/01-dockerfile-quality/Dockerfile

docker images localhost:5000/app
```

3つのタグが**同じイメージID**を指していることを確認してください(タグは「イメージの
別名」であり、コピーではありません)。

```bash
docker images localhost:5000/app --format "{{.Tag}}\t{{.ID}}"
```

`latest` は「移動する的」なので、代わりに使う場合の実務での位置づけも押さえておきます。
`latest` を付けるとしても、それは「あくまでこのビルド時点の最新を指す便宜的なタグ」であり、
**デプロイの根拠には常に不変(immutable)なタグかdigestを使う**というのが鉄則です。

```bash
docker push localhost:5000/app:${VERSION}
docker push localhost:5000/app:sha-${GIT_SHA}

# digestで一意に指し示す(タグが後で上書きされても、このdigestは同じイメージを指し続ける)
docker inspect --format '{{index .RepoDigests 0}}' localhost:5000/app:${VERSION}
```

### 動作確認

- `docker images` で `${VERSION}` / `${VERSION}-${GIT_SHA}` / `sha-${GIT_SHA}` の
  3タグが同一の `IMAGE ID` を指していること
- `docker inspect --format '{{index .RepoDigests 0}}'` でdigest(`sha256:...`)付きの
  参照が取得できること。これを使えば「タグが後から差し替えられても、当時デプロイした
  イメージそのものを再現できる」ことを理解できていればOKです

後片付け:

```bash
docker buildx rm hands-on-builder
docker rm -f local-registry
```

---

## 理解度確認

1. `docker build`(通常のビルド)で作ったイメージを、そのままarm64サーバにデプロイすると
   何が起きる可能性がありますか?
2. マルチプラットフォームビルドの結果を `--load` でローカルのDockerイメージ一覧に
   読み込めないのはなぜですか?確認したい場合はどうすればよいですか?
3. 本番運用で `latest` タグだけに頼るとどのような事故につながりますか?具体例を1つ挙げてください。
4. 「デプロイの根拠には不変なタグかdigestを使う」とはどういうことですか?タグと
   digestの違いも含めて説明してください。

<details>
<summary>解答例(クリックで表示)</summary>

1. イメージがビルド時のマシンのCPUアーキテクチャ向けにしかビルドされていないため、
   異なるアーキテクチャ(例: amd64向けのイメージをarm64サーバで動かす)では
   `exec format error` のような実行時エラーで起動できない可能性がある。
2. マルチプラットフォームの結果は複数アーキテクチャ分のイメージをまとめた
   「マニフェストリスト」であり、ローカルのDockerイメージストアには「1アーキテクチャ
   ぶんの1イメージ」という概念しかなくロードできないため。確認するには
   `--push` でレジストリに送り `docker buildx imagetools inspect` で見るか、
   `--platform` を1つに絞って `--load` する。
3. `latest` を本番でpullし直した際に、意図せず別のバージョンのイメージに切り替わって
   しまう。ロールバックしたくても「1つ前の`latest`が何だったか」をタグ名からは
   判別できない。
4. タグ(例: `latest`, `1.0.0`)は「その時点でどのイメージを指すか」を後から
   差し替えられるラベルに過ぎないが、digest(`sha256:...`)はイメージの内容から
   計算されるハッシュ値で、指すイメージの中身が変わることは絶対にない。デプロイ記録に
   digestを残しておけば、後でタグが上書きされても「あの時デプロイしたのはまさにこれ」
   と一意に再現できる。

</details>

次は [`05-security-lite/README.md`](../05-security-lite/README.md) に進んでください。
