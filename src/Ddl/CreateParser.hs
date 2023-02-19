module Ddl.CreateParser where

import Control.Applicative (asum, optional, many)

import Data.List.NonEmpty (NonEmpty (..), head, (<|))
import Data.Void (Void)
import Data.Text (Text)

import qualified HeadedMegaparsec as HM
import qualified PostgresqlSyntax.Ast as A
import qualified PostgresqlSyntax.Parsing as P

import Ddl.Extras

-- create

data CreateStmt =
  CreateTable TableDef
  | CreateIndex IndexDef
  deriving (Show)

type CreateColumnList = NonEmpty CreateColumnItem
data TableDef = TableDef A.Ident CreateColumnList
  deriving (Show)

data IndexDef = IndexDef
  deriving (Show)

data CreateColumnItem = CreateColumnItem A.Ident ColumnSpec
  deriving (Show)

data ColumnSpec =
  IntCS
  | VarcharCS (Maybe Int)
  deriving (Show)

data ConstrintSpec =
  TodoST
  deriving (Show)


createStmt :: HM.HeadedParsec Void Text CreateStmt
createStmt = do
  P.keyword "create"
  space1
  a <- asum [
      indexCreate
      , tableCreate
    ]
  return $ a


tableCreate = do
  tOpts <- optional tableKind
  P.keyword "table"
  space1
  -- [ IF NOT EXISTS ]
  a <- P.ident
  space1
  b <- P.inParens columnDefList
  return . CreateTable $ TableDef a b


tableKind = do
  a <- optional (
          asum [
            P.keyword "global"
            , P.keyword "local"
          ]
          *> space1
        )
  b <- asum [
          P.keyword "temporary"
          , P.keyword "temp"
        ]
  space1
  c <- optional (P.keyword "unlogged" *> space1)
  return (a, b, c)


columnDefList = sep1 P.commaSeparator columnDefItem

columnDefItem = do
  -- Ident
  a <- P.colId
  HM.endHead
  -- Type definition
  space1
  b <- colDefinition
  c <- optional constraintDef
  return $ CreateColumnItem a b


colDefinition =
  asum [
      do
      P.keyword "int"
      return $ IntCS
    , do
      P.keyword "integer"
      return $ IntCS
    , do
      P.keyword "varchar"
      a <- optional (
          P.inParens decimal
        )
      return $ VarcharCS a
  ]

constraintDef = do
  a <- optional (do
      space1
      P.keyword "constraint"
      space1
      P.ident
      return TodoST
    )
  b <- many $ asum [
      nullity
      , checkExpr
      , defaultExpr
      , generatedExpr
      , unicity
      , primaryKey
      , referenceDef
      , deferrecity
      , initiallity
    ]
  return TodoST


nullity = do
  space1
  a <- optional ( P.keyword "not" *> space1 )
  P.keyword "null"
  return TodoST

checkExpr = do
  space1
  P.keyword "check"
  space1
  a <- P.inParens P.ident      -- TODO: use expression
  b <- optional ( do
      P.keyword "no"
      space1
      P.keyword "inherit"
    )
  return TodoST

defaultExpr = do
  space1
  P.keyword "default"
  space1
  a <- P.ident     -- TODO: use expression
  return TodoST

generatedExpr = do
  space1
  P.keyword "generated"
  space1
  a <- asum [
        do
        P.keyword "always"
        space1
        P.keyword "as"
        space1
        c <- asum [
            do
              P.inParens P.ident
              space1
              P.keyword "stored"
              return TodoST
            , do
              P.keyword "identity"
              space1
              b <- optional ( P.inParens P.ident )    -- TODO: use sequence_options
              return TodoST
          ]
        return TodoST
      , do
        P.keyword "by"
        space1
        P.keyword "default"
        space1
        P.keyword "as"
        space1
        P.keyword "identity"
        space1
        b <- optional (
            P.inParens P.ident    -- TODO: use sequence_options
          )
        return TodoST
    ]
  return TodoST

unicity = do
  space1
  P.keyword "unique"
  a <- optional ( do
      space1
      P.keyword "nulls"
      space1
      b <- optional ( P.keyword "not" *> space1 )
      P.keyword "distinct"
      c <- P.ident     -- TODO: use index_parameters
      return TodoST
    )
  return TodoST

primaryKey = do
  space1
  P.keyword "primary"
  space1
  P.keyword "key"
  space1
  a <- P.ident -- TODO: use index_parameters
  return TodoST

referenceDef = do
  space1
  P.keyword "references"
  space1
  a <- P.ident
  b <- optional ( space *> P.inParens P.ident )
  c <- optional ( do
      space1
      P.keyword "match"
      space1
      d <- asum [
          P.keyword "full"
          , P.keyword "partial"
          , P.keyword "simple"
        ]
      return TodoST
    )
  d <- optional ( do
      space1
      P.keyword "on"
      space1
      P.keyword "delete"
      e <- referAction
      f <- optional ( do
          space1
          P.keyword "on"
          space1
          P.keyword "update"
          space1
          referAction
        )
      return TodoST
    )
  return TodoST


-- { NO ACTION | RESTRICT | CASCADE | SET NULL [ ( column_name [, ... ] ) ] | SET DEFAULT [ ( column_name [, ... ] ) ] }
referAction = do
  space1
  asum [
      do
      P.keyword "no"
      space1
      P.keyword "action"
      return TodoST
    , do
      P.keyword "restrict"
      return TodoST
    , do
      P.keyword "cascade"
      return TodoST
    , do
      P.keyword "set"
      space1
      a <- asum [
          do
            P.keyword "null"
            sep1 P.commaSeparator P.ident
            return TodoST
          , do
            P.keyword "default"
            sep1 P.commaSeparator P.ident
            return TodoST
        ]
      return TodoST
    ]
  return TodoST

deferrecity = do
  space1
  b <- optional ( P.keyword "not" *> space1 )
  P.keyword "deferrable"
  return TodoST

initiallity = do
  space1
  P.keyword "initially"
  space1
  asum [
      P.keyword "deffered"
      , P.keyword "immediate"
    ]
  return TodoST



indexCreate = do
  P.keyword "index"
  return . CreateIndex $ IndexDef

{-
CREATE [ [ GLOBAL | LOCAL ] { TEMPORARY | TEMP } | UNLOGGED ] TABLE [ IF NOT EXISTS ] table_name ( [
  { column_name data_type [ COMPRESSION compression_method ] [ COLLATE collation ] [ column_constraint [ ... ] ]
    | table_constraint
    | LIKE source_table [ like_option ... ] }
    [, ... ]
] )
[ INHERITS ( parent_table [, ... ] ) ]
[ PARTITION BY { RANGE | LIST | HASH } ( { column_name | ( expression ) } [ COLLATE collation ] [ opclass ] [, ... ] ) ]
[ USING method ]
[ WITH ( storage_parameter [= value] [, ... ] ) | WITHOUT OIDS ]
[ ON COMMIT { PRESERVE ROWS | DELETE ROWS | DROP } ]
[ TABLESPACE tablespace_name ]

CREATE [ [ GLOBAL | LOCAL ] { TEMPORARY | TEMP } | UNLOGGED ] TABLE [ IF NOT EXISTS ] table_name
    OF type_name [ (
  { column_name [ WITH OPTIONS ] [ column_constraint [ ... ] ]
    | table_constraint }
    [, ... ]
) ]
[ PARTITION BY { RANGE | LIST | HASH } ( { column_name | ( expression ) } [ COLLATE collation ] [ opclass ] [, ... ] ) ]
[ USING method ]
[ WITH ( storage_parameter [= value] [, ... ] ) | WITHOUT OIDS ]
[ ON COMMIT { PRESERVE ROWS | DELETE ROWS | DROP } ]
[ TABLESPACE tablespace_name ]

CREATE [ [ GLOBAL | LOCAL ] { TEMPORARY | TEMP } | UNLOGGED ] TABLE [ IF NOT EXISTS ] table_name
    PARTITION OF parent_table [ (
  { column_name [ WITH OPTIONS ] [ column_constraint [ ... ] ]
    | table_constraint }
    [, ... ]
) ] { FOR VALUES partition_bound_spec | DEFAULT }
[ PARTITION BY { RANGE | LIST | HASH } ( { column_name | ( expression ) } [ COLLATE collation ] [ opclass ] [, ... ] ) ]
[ USING method ]
[ WITH ( storage_parameter [= value] [, ... ] ) | WITHOUT OIDS ]
[ ON COMMIT { PRESERVE ROWS | DELETE ROWS | DROP } ]
[ TABLESPACE tablespace_name ]

where column_constraint is:

[ CONSTRAINT constraint_name ]
{ NOT NULL |
  NULL |
  CHECK ( expression ) [ NO INHERIT ] |
  DEFAULT default_expr |
  GENERATED ALWAYS AS ( generation_expr ) STORED |
  GENERATED { ALWAYS | BY DEFAULT } AS IDENTITY [ ( sequence_options ) ] |
  UNIQUE [ NULLS [ NOT ] DISTINCT ] index_parameters |
  PRIMARY KEY index_parameters |
  REFERENCES reftable [ ( refcolumn ) ] [ MATCH FULL | MATCH PARTIAL | MATCH SIMPLE ]
    [ ON DELETE referential_action ] [ ON UPDATE referential_action ] }
[ DEFERRABLE | NOT DEFERRABLE ] [ INITIALLY DEFERRED | INITIALLY IMMEDIATE ]

and table_constraint is:

[ CONSTRAINT constraint_name ]
{ CHECK ( expression ) [ NO INHERIT ] |
  UNIQUE [ NULLS [ NOT ] DISTINCT ] ( column_name [, ... ] ) index_parameters |
  PRIMARY KEY ( column_name [, ... ] ) index_parameters |
  EXCLUDE [ USING index_method ] ( exclude_element WITH operator [, ... ] ) index_parameters [ WHERE ( predicate ) ] |
  FOREIGN KEY ( column_name [, ... ] ) REFERENCES reftable [ ( refcolumn [, ... ] ) ]
    [ MATCH FULL | MATCH PARTIAL | MATCH SIMPLE ] [ ON DELETE referential_action ] [ ON UPDATE referential_action ] }
[ DEFERRABLE | NOT DEFERRABLE ] [ INITIALLY DEFERRED | INITIALLY IMMEDIATE ]

and like_option is:

{ INCLUDING | EXCLUDING } { COMMENTS | COMPRESSION | CONSTRAINTS | DEFAULTS | GENERATED | IDENTITY | INDEXES | STATISTICS | STORAGE | ALL }

and partition_bound_spec is:

IN ( partition_bound_expr [, ...] ) |
FROM ( { partition_bound_expr | MINVALUE | MAXVALUE } [, ...] )
  TO ( { partition_bound_expr | MINVALUE | MAXVALUE } [, ...] ) |
WITH ( MODULUS numeric_literal, REMAINDER numeric_literal )

index_parameters in UNIQUE, PRIMARY KEY, and EXCLUDE constraints are:

[ INCLUDE ( column_name [, ... ] ) ]
[ WITH ( storage_parameter [= value] [, ... ] ) ]
[ USING INDEX TABLESPACE tablespace_name ]

exclude_element in an EXCLUDE constraint is:

{ column_name | ( expression ) } [ opclass ] [ ASC | DESC ] [ NULLS { FIRST | LAST } ]

referential_action in a FOREIGN KEY/REFERENCES constraint is:

{ NO ACTION | RESTRICT | CASCADE | SET NULL [ ( column_name [, ... ] ) ] | SET DEFAULT [ ( column_name [, ... ] ) ] }

----
CREATE [ UNIQUE ] INDEX [ CONCURRENTLY ] [ [ IF NOT EXISTS ] name ] ON [ ONLY ] table_name [ USING method ]
    ( { column_name | ( expression ) } [ COLLATE collation ] [ opclass [ ( opclass_parameter = value [, ... ] ) ] ] [ ASC | DESC ] [ NULLS { FIRST | LAST } ] [, ...] )
    [ INCLUDE ( column_name [, ...] ) ]
    [ NULLS [ NOT ] DISTINCT ]
    [ WITH ( storage_parameter [= value] [, ... ] ) ]
    [ TABLESPACE tablespace_name ]
    [ WHERE predicate ]

======================================================

Name				          Aliases				        Description
bigint				        int8				          signed eight-byte integer
bigserial				      serial8				        autoincrementing eight-byte integer
bit [ (n) ]				 		                      fixed-length bit string
bit varying [ (n) ]		varbit [ (n) ]				variable-length bit string
boolean				        bool				          logical Boolean (true/false)
box				 				                          rectangular box on a plane
bytea				 				                        binary data (“byte array”)
character [ (n) ]				char [ (n) ]				fixed-length character string
character varying [ (n) ]		varchar [ (n) ]				variable-length character string
cidr				 				                        IPv4 or IPv6 network address
circle				 				                      circle on a plane
date				 				                        calendar date (year, month, day)
double precision				float8				      double precision floating-point number (8 bytes)
inet				 				                        IPv4 or IPv6 host address
integer				          int, int4				    signed four-byte integer
interval [ fields ] [ (p) ]				 				  time span
json				 				                        textual JSON data
jsonb				 				                        binary JSON data, decomposed
line				 				                        infinite line on a plane
lseg				 				                        line segment on a plane
macaddr				 				                      MAC (Media Access Control) address
macaddr8				 				                    MAC (Media Access Control) address (EUI-64 format)
money				 				                        currency amount
numeric [ (p, s) ]			decimal [ (p, s) ]	  exact numeric of selectable precision
path				 				                        geometric path on a plane
pg_lsn				 				                      PostgreSQL Log Sequence Number
pg_snapshot				 				                  user-level transaction ID snapshot
point				 				                        geometric point on a plane
polygon				 				                      closed geometric path on a plane
real                    float4				      single precision floating-point number (4 bytes)
smallint				        int2				        signed two-byte integer
smallserial				      serial2				      autoincrementing two-byte integer
serial				          serial4				      autoincrementing four-byte integer
text				 				                        variable-length character string
time [ (p) ] [ without time zone ]				 	    time of day (no time zone)
time [ (p) ] with time zone				  timetz				time of day, including time zone
timestamp [ (p) ] [ without time zone ]				 	  date and time (no time zone)
timestamp [ (p) ] with time zone	  timestamptz				date and time, including time zone
tsquery				 				                      text search query
tsvector				 				                    text search document
txid_snapshot				 				                user-level transaction ID snapshot (deprecated; see pg_snapshot)
uuid				 				                        universally unique identifier
xml				 				                          XML data
-}
