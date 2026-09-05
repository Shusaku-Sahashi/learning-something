package lisp

// Parse はソースコード全体を読み込み、トップレベルに並んだS式をValueのスライスとして返します。
// 例えば "(+ 1 2) (* 3 4)" を渡すと、2つのList値が返ります。
// このオーケストレーション部分は実装済みです。読み解いて、readExpr の役割を理解してください。
func Parse(src string) ([]Value, error) {
	tokens, err := Tokenize(src)
	if err != nil {
		return nil, err
	}

	var exprs []Value
	for len(tokens) > 0 {
		var expr Value
		expr, tokens, err = readExpr(tokens)
		if err != nil {
			return nil, err
		}
		exprs = append(exprs, expr)
	}
	return exprs, nil
}

// STEP 2: 構文解析器 (パーサー) を実装しましょう。
//
// readExpr は先頭のトークン列から1つのS式を読み取り、
// 読み取った値と「残りのトークン列」を返します。
//
// 考え方（トークンの先頭で分岐します）:
//   - トークン列が空                 => エラー（式の途中で入力が終わった）
//   - 先頭が "("                    => readList に処理を委ねる（"(" の次から)
//   - 先頭が ")"                    => エラー（対応する "(" がない）
//   - 先頭が "'"                    => 続きを再帰的に readExpr で読み、
//     (quote 読んだ式) という2要素のListにする
//   - それ以外（アトム）              => parseAtom で値に変換する
//
// ヒント: List{Symbol("quote"), quoted} のように書けば (quote ...) が作れます。
func readExpr(tokens []string) (Value, []string, error) {
	// TODO: 実装してください。
	panic("TODO: readExpr を実装してください")
}

// readList は最初の "(" を消費した状態で呼ばれ、対応する ")" までを読み取ります。
// ")" が見つかるまで readExpr を繰り返し呼び出し、読み取った値を1つのListに集めていきます。
//
// ヒント:
//   - トークンが尽きたのに ")" が来なければエラー（リストが閉じられていない）。
//   - readExpr は「残りのトークン列」を返すので、次のループではそれを使ってください。
func readList(tokens []string) (Value, []string, error) {
	// TODO: 実装してください。
	panic("TODO: readList を実装してください")
}

// parseAtom は1つのトークン（"(" ")" "'" 以外）を Number / Bool / String / Symbol に変換します。
//
// 変換ルール:
//   - "#t" / "#f"                         => Bool(true) / Bool(false)
//   - 前後が '"' で囲まれている（文字列リテラル）  => String（strconv.Unquote が便利です）
//   - strconv.ParseFloat が成功する          => Number
//   - それ以外                             => Symbol（変数名や関数名とみなす）
func parseAtom(tok string) Value {
	// TODO: 実装してください。"strconv" パッケージ (strconv.ParseFloat, strconv.Unquote) を
	// import して使います。
	panic("TODO: parseAtom を実装してください")
}
