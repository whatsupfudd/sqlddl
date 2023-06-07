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

import Ddl.Ast.Create (CreateStmt)
import Ddl.Ast.Alter (AlterStmt)
import Ddl.CreateParser (createStmt)
import Ddl.AlterParser (alterStmt)
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


{-
DDL (Data Definition Language)
 -- create, drop, alter, truncate
DML/DQL (Data Manipulation Language // Data Query Language)
 -- insert, updated, delete, call, explain, lock // select
DCL (Data Control Language)
 -- grant, revoke
TCL (Transactional Control Language)
 -- commit, savepoint, rollback, set transaction, set constraint


----------
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);

ALTER SCHEMA public OWNER TO postgres;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;
COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;

-}
