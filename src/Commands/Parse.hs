module Commands.Parse where

import Data.Text (Text, unpack)

import Ddl.Parsers (parseDdl)
import Ddl.Interpret (convert)

import qualified Options.Runtime as Rto


parseCmd :: Text -> Rto.RunOptions -> IO ()
parseCmd stmt rtOpts = do
  putStrLn "@[parseCmd] starting."
  let
    rezA = parseDdl stmt
  case rezA of
    Left err -> do
      putStrLn $ "@[parseCmd] parser err: "
      putStr err
    Right ddlStmtList ->
      let
        rezB = convert ddlStmtList
      in
      case rezB of
        Right table -> putStrLn $ "@[parseCmd] rez: " <> show table
        Left errMsg -> putStrLn $ "@[parseCmd] err: " <> unpack errMsg
