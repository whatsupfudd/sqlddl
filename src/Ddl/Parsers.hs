module Ddl.Parsers
 (
    DdlStmt (..)
    , parseDdl
    , module Ddl.CreateParser
    , module Ddl.AlterParser
 )
where


import Control.Applicative (asum)
import Data.Text (Text)
import Data.List.NonEmpty (NonEmpty)

import Ddl.CreateParser
import Ddl.AlterParser

import qualified PostgresqlSyntax.Parsing as P

import Ddl.Extras (sep1, semicolonSeparator)


data DdlStmt =
  CreateDS CreateStmt
  | AlterDS AlterStmt
  deriving (Show)


-- all the DDL statements:

parseDdl :: Text -> Either String (NonEmpty DdlStmt)
parseDdl = P.run ddlStmtList


ddlStmtList = sep1 semicolonSeparator ddlStmt


ddlStmt =
  asum [
    do
      a <- createStmt
      return $ CreateDS a
    , do
      b <- alterStmt
      return $ AlterDS b
  ]
