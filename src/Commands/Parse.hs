module Commands.Parse where

import Data.Text (Text, unpack)

import Ddl.Parsers (parseDdl)
import Ddl.Interpret (convert)
import Ddl.Printer (showCompact, showIndiv)


import qualified Options.Runtime as Rto


parseCmd :: Text -> Rto.RunOptions -> IO ()
parseCmd stmt rtOpts = do
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
        Right (tableMap, leftOver) -> do
          putStrLn $ "@[parseCmd] rez: " <> show tableMap <> "\n"
          mapM_ (\m -> do
             putStrLn "Compact:"
             putStrLn . unpack $ showCompact m
             putStrLn "\nIndiv:"
             putStrLn . unpack $ showIndiv m
            ) tableMap
        Left errMsg -> putStrLn $ "@[parseCmd] err: " <> unpack errMsg
