module Ddl.Ast.Create where

import Data.List.NonEmpty (NonEmpty (..))

import qualified PostgresqlSyntax.Ast as A


data CreateStmt =
  CreateTable TableDef
  | CreateIndex IndexDef
  | CreateSchema SchemaDef
  | CreateSequence SequenceDef
  deriving (Show)


data TableDef = TableDef {
    kind :: Maybe TableKind
    , ifNEFlag :: Bool
    , name :: A.Ident
    , columnsList :: CreateColumnList
  }
  deriving (Show)


data TableKind = TableKind {
    locality :: Maybe Locality
    , tempFlag :: Bool
    , logged :: Maybe Bool
  }
  deriving (Show)


data Locality =
  GlobalLC
  | LocalLC
  deriving (Show)

type CreateColumnList = NonEmpty CreateColumnItem


data CreateColumnItem = CreateColumnItem A.Ident ColumnSpec (Maybe ConstraintDef)
  deriving (Show)

data ColumnSpec =
  -- TODO: put all the types.
  IntCS
  | VarcharCS (Maybe Int)
  deriving (Show)

-- "[constraint <ident>]" <constraint>+
data ConstraintDef = ConstraintDef {
    cName :: Maybe A.Ident
    , specList :: NonEmpty ConstraintSpec
  }
  deriving (Show)


data ConstraintSpec =
  -- TODO: put all the constraints.
  TodoST
  | IfNotExistCS
  | NullityCS
  | CheckExprCS
  | DefaultCS A.AExpr
  | GeneratedExprCS
  | UnicityCS
  | PrimaryKeyCS
  | ReferenceCS
  | DeferrecityCS
  | InitiallityCS
  deriving (Show)


-- **** INDEX ****

data IndexDef = IndexDef {
    uniqueFlag :: Bool
    , concurFlag :: Bool
    , ifNEFlag :: Bool
    , name :: A.Ident
    , onlyFlag :: Bool
  }
  deriving (Show)


-- **** SCHEMA ****

data SchemaRoleSpec =
  CurrentRoleSR
  | CurrentUserSR
  | SessionUserSR
  | IdentSR A.Ident
  deriving (Show)

data SchemaDef = SchemaDef {
    ifNEFlag :: Bool
    , name :: Maybe A.Ident
    , authRole :: Maybe SchemaRoleSpec
    , createStmts :: Maybe (NonEmpty CreateStmt)
  }
  deriving (Show)


-- **** SEQUENCE ****

data SeqBound =
  NoValueSB
  | SetValueSB Int
  deriving (Show)

data SeqOwner =
  NoOwnerSO
  | OwnerSO A.Ident
  deriving (Show)

data SequenceDef = SequenceDef {
    ifNEFlag :: Bool
    , name :: A.Ident
    , asName :: Maybe A.Ident
    , increment :: Maybe Int
    , minValue :: Maybe SeqBound
    , maxValue :: Maybe SeqBound
    , start :: Maybe Int
    , cache :: Maybe Int
    , doCycle :: Maybe Bool
    , owner :: Maybe SeqOwner
  }
  deriving (Show)


