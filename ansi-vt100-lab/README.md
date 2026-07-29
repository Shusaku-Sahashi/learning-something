# ANSI / VT100 エスケープシーケンス Lab (Go)

ターミナルに色をつけたり、カーソルを自由に動かしたり、[IRIS](https://github.com/versenilvis/IRIS) のような
サジェストボックス（入力補完のドロップダウン）を描いたりする仕組みを、実際に動く Go のサンプルを
書きながら理解するための学習用プロジェクトです。自作の `ansi` パッケージで生のエスケープシーケンスを
自分の目で確認できるようにしてあります（外部ライブラリは、生ターミナルモードのために標準的に使われる
`golang.org/x/term` のみ使用しています）。

## 前提知識: エスケープシーケンスとは

ターミナルは基本的に「文字を受け取って表示する」だけの装置ですが、特定のバイト列（`ESC` = `0x1B` から
始まる）を受け取ると、それを「表示する文字」ではなく「命令」として解釈します。これが ANSI エスケープ
シーケンス（起源は VT100 などの DEC 端末の制御コード）です。

もっともよく使う形式が **CSI (Control Sequence Introducer)** です。

```
ESC [ <パラメータ> <最終バイト>
\x1b [ 31            m
```

- `\x1b[` : CSI の開始
- `31`    : パラメータ（この例では「前景色を赤にする」という意味のコード）
- `m`     : 最終バイト。`m` は SGR (Select Graphic Rendition = 文字装飾) を意味する

つまり `"\x1b[31m"` を出力すると、それ以降に出力する文字が赤色になり、`"\x1b[0m"` でリセットされます。

```go
fmt.Println("\x1b[31mこれは赤い文字です\x1b[0m")
```

## このリポジトリの構成

Go の慣習に従い、実行可能なサンプルはそれぞれ `cmd/<名前>/main.go` に分かれています。

```
ansi-vt100-lab/
├── go.mod / go.sum
├── internal/
│   └── ansi/
│       └── ansi.go               # エスケープシーケンスをまとめた自作の小さなパッケージ
└── cmd/
    ├── 01-hello-escape/          # 生のエスケープシーケンスで色を出す最小例
    ├── 02-cursor-movement/       # カーソルを自由な座標に移動させるアニメーション
    ├── 03-colors-and-styles/     # 16色 / 256色 / トゥルーカラー / 文字装飾
    ├── 04-erase-and-progress-bar/ # 行のクリア + \r でその場更新するプログレスバー
    ├── 05-alternate-screen-clock/ # vim/htop が使う「代替スクリーン」+ ライブ時計
    └── 06-suggest-box/           # 集大成: IRIS のようなサジェストボックス
```

`internal/ansi` は npm ならぬ Go module を使わず、`CSI = "\x1b["` から自分で組み立てた最小限のパッケージです。
実務では [`github.com/charmbracelet/lipgloss`](https://github.com/charmbracelet/lipgloss) や
[`github.com/gdamore/tcell`](https://github.com/gdamore/tcell) のようなライブラリを使いますが、まずは中身が
何をしているのかを理解するのがこの Lab の目的です。生ターミナルモード（1キーずつ入力を受け取るモード）
だけは OS ごとの `ioctl`/`termios` の違いを吸収する必要があるため、Go チーム公式の
[`golang.org/x/term`](https://pkg.go.dev/golang.org/x/term) を使っています。

## 実行方法

```bash
cd ansi-vt100-lab
go run ./cmd/01-hello-escape
go run ./cmd/02-cursor-movement
go run ./cmd/03-colors-and-styles
go run ./cmd/04-erase-and-progress-bar
go run ./cmd/05-alternate-screen-clock
go run ./cmd/06-suggest-box
```

初回は `go run` が `golang.org/x/term` を取得します（`go.sum` 済みなので追加の `go get` は不要です）。
まとめてビルドしたい場合は `go build ./...`。

途中で止まらない例（`02` / `05`）は `Ctrl+C` で終了してください。

## サンプルの解説

### 01. `hello-escape` — 最小の一歩
自作パッケージを使わず、生の `"\x1b[31m"` のような文字列を直接 `fmt.Println` するだけの例です。
`go run ./cmd/01-hello-escape | cat -v` のように `cat -v` へパイプすると、エスケープコードが
`^[[31m` という「見える文字」として表示されるので、実際にどんなバイト列が飛んでいるのか確認できます。

### 02. `cursor-movement` — カーソル移動
`CSI <row>;<col> H` (Cursor Position, 通称 CUP) を使って、画面上の好きな座標に文字を描きます。
`fmt.Println` は常に一番下に追記するだけですが、CUP を使えばターミナルを 2 次元のキャンバスとして
扱えるようになります。TUI アプリの基本はすべてこれです。`time.Ticker` と `signal.Notify` で
アニメーションループと `Ctrl+C` 終了処理を実装しています。

### 03. `colors-and-styles` — 色と文字装飾 (SGR)
ターミナルの配色には主に 3 段階あります。

| 方式 | シーケンス | 対応状況 |
| --- | --- | --- |
| 16色 | `ESC[30-37m` (前景) / `ESC[90-97m` (明るい系) | ほぼ全ターミナルで対応 |
| 256色 | `ESC[38;5;<n>m` | ほとんどのモダンターミナル |
| トゥルーカラー (24bit) | `ESC[38;2;<r>;<g>;<b>m` | ほとんどのモダンターミナル |

`bold` (`1`) や `underline` (`4`) のような文字装飾も同じ SGR の仲間で、`;` 区切りで複数指定できます
(例: `ESC[1;32m` = 太字 + 緑)。

### 04. `erase-and-progress-bar` — その場更新
プログレスバーやスピナーが「同じ行を上書きして更新している」ように見えるのは、次の 2 つの組み合わせです。

1. `\r` (キャリッジリターン) でカーソルを行頭に戻す（改行はしない）
2. `ESC[K` (Erase in Line, EL) でカーソルから行末までを消す

`\r` だけだと、前のフレームの方が長かった場合に文字が残ってしまうため、`EL` での消去が必須です。

### 05. `alternate-screen-clock` — 代替スクリーンバッファ
`vim` や `less`、`htop` を終了すると、実行前の画面にきれいに戻ります。これは `ESC[?1049h` で
「代替スクリーン」に切り替えてから描画し、終了時に `ESC[?1049l` で元のスクリーンに戻しているからです。
このサンプルはそこにライブ更新する時計を描画します。

### 06. `suggest-box` — 集大成: サジェストボックス
今回のきっかけになった IRIS のような「入力中にドロップダウンで候補を出す」UI を、フルスクリーンの
TUI フレームワークなしで実装した例です。ポイントは:

- `term.MakeRaw(fd)` (from `golang.org/x/term`) で 1 キーずつイベントを受け取る（これは ANSI ではなく
  OS/端末ドライバ側の話）
- 入力行と候補リストのために、あらかじめ空行を確保しておいてからカーソルをそこへ戻す
- 再描画のたびに: 入力行を `CursorToColumn(1)` + `EraseLine` でクリアして書き直す →
  `CursorDown(1)` で 1行ずつ候補欄に移動して同様に描き直す → 最後に `CursorUp(n)` で入力行まで戻る
- 選択中の候補だけ `ansi.Inverse` (反転表示) でハイライトする

**Esc キー と 矢印キーの見分け方。** 矢印キーは `ESC [ A` (上) / `ESC [ B` (下) のように、先頭が
単独の Esc キーと同じ `0x1b` から始まる 3 バイトのシーケンスとして届きます。両者を区別するため、
`0x1b` を受け取った直後は「矢印シーケンスの残り 2 バイトがすぐ届くはず」と考えて短時間だけ待ち、
何も届かなければ「単独の Esc キーが押された」と判断します（readline 系のライブラリが実際に使っている
テクニックです）。

実装のポイントとして、当初は `os.Stdin.SetReadDeadline` でこのタイムアウトを実現しようとしましたが、
環境によっては（実際、この Lab の動作確認環境でも）継承された標準入力の疑似端末に対して
`SetReadDeadline` が `"file type does not support deadline"` エラーを返し、機能しませんでした。
そこで代わりに、標準入力を 1 バイトずつ読み続ける goroutine を 1 つ起動し、そのバイトを channel に
流し込む設計に変更しています。メインの goroutine 側は `select` + `time.After(50 * time.Millisecond)`
でその channel を待つだけなので、OS のファイルディスクリプタの deadline サポートに依存しません。
`cmd/06-suggest-box/main.go` の `startByteReader` / `readKey` のコメントに詳細があります。
goroutine・channel・`select` を組み合わせた、Go らしい並行処理の実例にもなっています。

Backspace は端末によって `0x7f` (DEL) だったり `\b` (0x08) だったりするため、両方を見ています。

## エスケープシーケンス早見表

| 目的 | シーケンス | 説明 |
| --- | --- | --- |
| カーソル上/下/右/左 | `ESC[nA` / `ESC[nB` / `ESC[nC` / `ESC[nD` | n 行/列分カーソルを動かす |
| カーソル絶対移動 | `ESC[row;colH` | (1,1) が左上 |
| カーソル列だけ移動 | `ESC[nG` | 現在の行の n 列目へ |
| カーソル位置保存/復元 | `ESC7` / `ESC8` | DECSC / DECRC |
| カーソル非表示/表示 | `ESC[?25l` / `ESC[?25h` | 点滅するカーソルを消す/戻す |
| 画面消去 | `ESC[2J` | 画面全体を消去 |
| 行消去 | `ESC[2K` | カーソルがある行を消去 |
| 文字色リセット | `ESC[0m` | すべてのSGR装飾を解除 |
| 太字 / 下線 / 反転 | `ESC[1m` / `ESC[4m` / `ESC[7m` | SGR |
| 256色前景/背景 | `ESC[38;5;nm` / `ESC[48;5;nm` | n = 0〜255 |
| トゥルーカラー前景/背景 | `ESC[38;2;r;g;bm` / `ESC[48;2;r;g;bm` | 24bit RGB |
| 代替スクリーン ON/OFF | `ESC[?1049h` / `ESC[?1049l` | vim/htop などが使う |

## 次に試すと理解が深まること

- `internal/ansi` に無い `ESC[6n` (Device Status Report、カーソル位置を問い合わせる) を実装して、
  現在のカーソル座標を取得してみる
- `06-suggest-box` にターミナル幅 (`term.GetSize`) を考慮したレイアウト崩れ対策を入れてみる
- 同じサジェストボックスを [`github.com/charmbracelet/bubbletea`](https://github.com/charmbracelet/bubbletea)
  のような TUI フレームワークで書き直し、自作パッケージとの違いを比べてみる
- IRIS のソースコードを読んで、この Lab で出てきたのと同じシーケンス（カーソル移動・消去・SGR）が
  どこでどう使われているか探してみる
