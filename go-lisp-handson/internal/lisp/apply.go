package lisp

// STEP 3: 関数適用 Apply を実装しましょう。
//
// Apply は関数値 fn を引数 args に適用します。fn の型によって処理を分けます。
//
//   - *Builtin の場合: f.Fn(args) をそのまま呼び出して返す。
//   - *Lambda の場合 :
//     1. 引数の数 (len(args)) がパラメータの数 (len(f.Params)) と一致するか確認する。
//     一致しなければエラーを返す。
//     2. f.Env を親とする新しい環境 callEnv を作る（NewEnv(f.Env)）。
//     ここがポイントです。呼び出した瞬間の環境ではなく、
//     「関数が定義された時点の環境」を親にすることで、クロージャが実現されます。
//     3. callEnv に、パラメータ名と引数の値を1つずつ Define する。
//     4. evalBody(f.Body, callEnv) で本体を評価し、その結果を返す。
//   - それ以外の型: 関数として呼び出せないのでエラーを返す。
func Apply(fn Value, args []Value) (Value, error) {
	// TODO: 実装してください。
	panic("TODO: Apply を実装してください")
}
