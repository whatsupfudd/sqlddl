module Ddl.Ast.Alter where

import qualified PostgresqlSyntax.Ast as A

data AlterStmt =
  AlterTable A.Ident
  deriving (Show)
