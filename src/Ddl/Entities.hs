module Ddl.Entities where

import Data.Text (Text)
import qualified Data.Map as Mp

import qualified PostgresqlSyntax.Ast as A


-- Overall contaxt:
data DefContext = DefContext {
    tables :: TableMap
    , indices :: IndexMap
    , sequences :: SeqMap
    -- , leftOver :: 
  }

-- SQL objects
type IndexMap = Mp.Map Text Index
type SeqMap = Mp.Map Text Sequence
type TableMap = Mp.Map Text Table
type ColumnMap = Mp.Map Text Column 
type ConstraintMap = Mp.Map Text [ Constraint ]

data Index = Index { 
    name :: Text
  }
  deriving (Show)


data Sequence = Sequence { 
    name :: Text
  }
  deriving (Show)


data Table = Table {
    name :: Text
    , columns :: ColumnMap
    , constraints :: ConstraintMap
    , referencedBy :: [ String ]
  }
  deriving (Show)


data Column = Column {
    name :: Text
    , sType :: SqlType
    , hType :: HkType
    , constraints :: [ Constraint ]
  }
  deriving (Show)


data SqlType =
  IntST
  | VarCharST (Maybe Int)
  deriving (Show)


data Constraint = 
  CheckCN
  | DefaultCN A.AExpr
  | DefferCN
  | GenerateCN
  | InitiallyCN
  | NullityCN
  | PrimaryKeyCN
  | ReferenceCN
  | UnicityCN
  deriving (Show)


data HkType = 
  Int4HT
  | TextHT
  | TimeHT
  | UnknownHT
  deriving (Show)

