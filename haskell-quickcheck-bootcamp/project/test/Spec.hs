-- | テストのエントリポイント。
--
-- cabal の exitcode-stdio-1.0 テストなので、
-- 終了コード 0 で成功、それ以外で失敗として扱われます。
--
-- 実行例:
--   cabal test                          -- 既定 (dev プロファイル)
--   QC_PROFILE=ci cabal test            -- 多めに回す
--   QC_PROFILE=nightly cabal test       -- 夜間バッチ用
--   QC_SEED=12345 cabal test            -- シードを固定して再現
--
--   cabal test --test-show-details=direct  -- 出力をそのまま見る
module Main (main) where

import System.Environment (lookupEnv)
import Test.QuickCheck (Args (..))
import Test.QuickCheck.Random (mkQCGen)

import qualified Props.Interval
import qualified Props.Queue
import qualified Props.Regression
import qualified Props.Text
import Runner

main :: IO ()
main = do
  profile <- lookupEnv "QC_PROFILE"
  seedStr <- lookupEnv "QC_SEED"

  let baseArgs = case profile of
        Just "ci"      -> ciArgs
        Just "nightly" -> nightlyArgs
        _              -> devArgs

      args = case seedStr of
        Just s | [(n, "")] <- reads s -> baseArgs { replay = Just (mkQCGen n, 0) }
        _                             -> baseArgs

  putStrLn ("profile   : " ++ maybe "dev" id profile)
  putStrLn ("maxSuccess: " ++ show (maxSuccess args))
  putStrLn ("maxSize   : " ++ show (maxSize args))
  putStrLn ("seed      : " ++ maybe "(random)" id seedStr)

  runGroups args
    [ Props.Queue.group
    , Props.Text.group
    , Props.Interval.group
    , Props.Regression.group
    ]
