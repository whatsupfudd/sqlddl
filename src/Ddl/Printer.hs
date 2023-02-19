module Ddl.Printer where

import Data.Text (Text, pack)
import qualified Data.Map as Mp
import Ddl.Interpret


showCompact :: Table -> Text
showCompact table =
  -- compact fields + constratings + indices
  let
    (colText, _) = Mp.foldl (\(accum, pos) c -> (accum <> columnCompact c pos, pos+1) ) (tableProlog table, 0) table.columns
  in
  colText <> "\n);"


showIndiv :: Table -> Text
showIndiv table =
  tableProlog table
  <> "\n);"


tableProlog :: Table -> Text
tableProlog table =
  "create table " <> table.name <> " ("


columnCompact :: Column -> Int -> Text
columnCompact column pos =
  (if pos == 0 then "\n  " else "\n ,")
  <> column.name <> " " <> sqlType column.sType


sqlType :: SqlType -> Text
sqlType aType =
  case aType of
    IntST -> "int"
    VarCharST mbN ->  case mbN of
          Nothing -> "varchar"
          Just aN -> "varchar (" <> (pack . show $  aN) <> ")"
