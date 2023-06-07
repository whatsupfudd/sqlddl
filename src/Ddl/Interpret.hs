module Ddl.Interpret where


import qualified Data.Map as Mp
import Data.Text (Text, unpack)
import Data.Vector (Vector)
import Data.List.NonEmpty (NonEmpty (..), head, (<|))
import qualified Data.List.NonEmpty as Ne
import Data.Void (Void)

import qualified PostgresqlSyntax.Ast as A

import Ddl.Parsers (DdlStmt (..))
import Ddl.Entities
import Ddl.Ast.Create
import Ddl.Ast.Alter


convert :: NonEmpty DdlStmt -> Either Text (TableMap, [AlterStmt])
convert stmts =
  convertCtxt (Mp.empty :: TableMap, []) stmts


convertCtxt :: (TableMap, [ AlterStmt ]) -> NonEmpty DdlStmt -> Either Text (TableMap, [AlterStmt])
convertCtxt (tableMap, leftOver) stmts =
  case Ne.head stmts of
    AlterDS alterSt ->
      case stmts of
        _ :| [] -> Right (tableMap, alterSt : leftOver)
        _ :| tailSt ->
          convertCtxt (tableMap, alterSt : leftOver) (Ne.fromList tailSt)
    CreateDS createSt ->
      let
        eiNewTable = tableConvert createSt
      in
      case eiNewTable of
        Left errMsg -> Left errMsg
        Right newTable ->
          case Mp.lookup newTable.name tableMap of
            Nothing ->
              let
                newMap = Mp.insert newTable.name newTable tableMap
              in
              case stmts of
                _ :| [] -> Right (newMap, leftOver)
                _ :| tailSt ->
                  convertCtxt (newMap, leftOver) (Ne.fromList tailSt)
            Just dupTable -> Left $ "@[convCtxt] dup table " <> newTable.name <> "."
  

tableConvert (CreateTable td) = -- (TableDef kind nexFlag ident columns)
  let
    name =
      case td.name of
        A.UnquotedIdent label -> label
        A.QuotedIdent label -> label
    eiColumns = columnsConvert td.columnsList
  in
  case eiColumns of
    Left errMsg -> Left errMsg
    Right colList ->
      Right $ Table name colList Mp.empty []
  -- TODO: extract colums


columnsConvert :: CreateColumnList -> Either Text ColumnMap
columnsConvert columns =
  foldl (\accum (CreateColumnItem ident colSpec constraints) ->
    let
      name =
        case ident of
          A.UnquotedIdent label -> label
          A.QuotedIdent label -> label
    in
    case fmap (Mp.lookup name) accum of
        Right (Just _) -> Left $ "@[convCol] dup: " <> name
        Right Nothing -> fmap (Mp.insert name (Column name (convertType colSpec) UnknownHT)) accum
        Left errMsg -> Left errMsg
    ) (Right $ Mp.empty) columns


convertType spec =
  case spec of
    IntCS -> IntST
    VarcharCS mbN -> VarCharST mbN
    
