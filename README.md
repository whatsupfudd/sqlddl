# SqlDdl

**Typed PostgreSQL schema parsing, analysis, transformation, and evolution
infrastructure for the FUDD ecosystem.**

SqlDdl is a Haskell library and early-stage command-line application for
turning SQL Data Definition Language (DDL) into structured, typed
representations that software can analyse and transform.

The current implementation begins with PostgreSQL-oriented parsing of
statements such as:

```sql
CREATE TABLE ...
CREATE INDEX ...
CREATE SCHEMA ...
CREATE SEQUENCE ...
ALTER TABLE ...
```

but parsing is only the first part of the intended system.

The longer-term role of SqlDdl in FUDD is to provide a **schema intelligence
layer**:

```text
SQL DDL source
     |
     v
lossless/source-aware DDL AST
     |
     v
canonical schema model
     |
     +------> validation and resolution
     |
     +------> canonical SQL generation
     |
     +------> schema comparison
     |
     +------> migration planning
     |
     +------> schema history
     |
     +------> Hasql compile-time verification
     |
     `------> Recycler / legacy modernisation
```

This makes SqlDdl supporting infrastructure for several larger FUDD
capabilities rather than simply a SQL parser.

The project is currently at an **early development stage**.

Large portions of the target architecture described in this README are not
yet implemented. Sections explicitly labelled *Target architecture* or
*Roadmap* describe intended development rather than current functionality.

The current package version is:

```text
0.1.0.0
```

---

## Contents

- [Role in the FUDD ecosystem](#role-in-the-fudd-ecosystem)
- [Why SqlDdl exists](#why-sqlddl-exists)
- [Current implementation](#current-implementation)
- [Target architecture](#target-architecture)
- [Getting started](#getting-started)
- [Current command-line interface](#current-command-line-interface)
- [Current parser API](#current-parser-api)
- [Current DDL AST](#current-ddl-ast)
- [Canonical schema model](#canonical-schema-model)
- [Parsing versus interpretation](#parsing-versus-interpretation)
- [Schema resolution and validation](#schema-resolution-and-validation)
- [SQL generation](#sql-generation)
- [Schema comparison](#schema-comparison)
- [Migration planning](#migration-planning)
- [Schema history](#schema-history)
- [Hasql and Hasql-TH integration](#hasql-and-hasql-th-integration)
- [Recycler integration](#recycler-integration)
- [Source traceability](#source-traceability)
- [Module map](#module-map)
- [Development roadmap](#development-roadmap)
- [Testing strategy](#testing-strategy)
- [Design principles](#design-principles)
- [Current limitations](#current-limitations)
- [Repository housekeeping](#repository-housekeeping)
- [License](#license)

---

# Role in the FUDD ecosystem

Relational schemas are executable descriptions of important parts of an
application's domain model.

A database schema contains information about:

```text
entities
attributes
types
identity
relationships
cardinality
constraints
defaults
indexes
ownership
dependency structure
```

For FUDD systems, SQL DDL should therefore be treated as **structured source
code**, not as an opaque collection of strings.

SqlDdl provides the layer that converts that source into a representation
other tools can reason about.

Its principal intended consumers are:

```text
                    +----------------+
                    |     SqlDdl     |
                    |                |
SQL DDL ----------> | parse          |
                    | normalize      |
                    | resolve        |
                    | validate       |
                    | compare        |
                    +-------+--------+
                            |
          +-----------------+------------------+
          |                 |                  |
          v                 v                  v
      Migrator          Recycler          Hasql / TH
          |                 |                  |
 schema evolution    legacy-system       compile-time
 migration plans     modernisation       SQL validation
```

Other FUDD tooling can later consume the same canonical schema model without
having to implement its own PostgreSQL parser.

---

# Why SqlDdl exists

There are several different problems that initially appear to require
independent SQL tooling.

For example:

### Migration generation

Given two versions of a schema:

```text
schema A
   |
   v
schema B
```

determine what changed and construct a safe migration plan.

### Embedded SQL verification

Given:

```sql
SELECT id, label
FROM project
WHERE owner_fk = $1
```

and a known schema, verify at compile time that:

```text
project exists
id exists
label exists
owner_fk exists
types are compatible
```

### Legacy-system analysis

Given a SQL dump from an old application, reconstruct:

```text
tables
relationships
constraints
dependencies
implicit domain structure
```

as part of Recycler's source-intelligence process.

### Schema history

Given schema definitions from successive Git revisions, derive:

```text
what changed
when it changed
what depends on the change
how the data model evolved
```

All of these tasks require the same foundational capability:

> parse DDL into a trustworthy typed representation of the database schema.

SqlDdl is intended to provide that shared foundation.

---

# Current implementation

The current source repository contains an initial implementation of four
layers:

```text
DDL text
   |
   v
statement parser
   |
   v
DDL AST
   |
   v
partial interpretation
   |
   v
small table model
   |
   v
partial SQL printer
```

The implementation is currently PostgreSQL-specific.

It uses:

```text
postgresql-syntax
headed-megaparsec
megaparsec
```

for parsing infrastructure.

---

## Current capability summary

| Capability | Status |
| --- | --- |
| Multiple semicolon-separated DDL statements | Initial implementation |
| `CREATE TABLE` | Partial |
| `CREATE INDEX` | Parser skeleton |
| `CREATE SCHEMA` | Partial parser |
| `CREATE SEQUENCE` | Partial parser |
| `ALTER TABLE` | Very early parser |
| `DROP` | Not implemented |
| `TRUNCATE` | Not implemented |
| SQL type model | Only `int` and `varchar` |
| Column constraints | Syntax partly recognized; semantics mostly TODO |
| Table constraints | Not implemented |
| Foreign-key model | Not implemented |
| Schema/name resolution | Not implemented |
| Dependency graph | Not implemented |
| Schema validation | Not implemented |
| Canonical SQL output | Very limited |
| Round-trip preservation | Not implemented |
| Schema diff | Not implemented in current repository |
| Migration planner | Not implemented |
| Git schema history | Not implemented |
| Hasql schema verification | Not implemented here |
| Recycler integration | Not implemented |
| Automated tests | Placeholder only |

The project should therefore be regarded as an architectural prototype rather
than a finished DDL library.

---

# Target architecture

The desired architecture separates several representations that solve
different problems.

```text
                     SQL source
                         |
                         v
              +----------------------+
              | Source DDL document  |
              |                      |
              | statements           |
              | exact identifiers    |
              | source ranges        |
              | comments/trivia      |
              | dialect information  |
              +----------+-----------+
                         |
                         v
              +----------------------+
              | Parsed DDL AST       |
              |                      |
              | CREATE / ALTER / ... |
              | expressions          |
              | type specifications  |
              | constraints          |
              +----------+-----------+
                         |
                         v
              +----------------------+
              | Canonical Schema     |
              |                      |
              | schemas              |
              | tables               |
              | columns              |
              | types                |
              | keys                 |
              | foreign keys         |
              | indexes              |
              | sequences            |
              +----------+-----------+
                         |
                 resolve / validate
                         |
                         v
              +----------------------+
              | Resolved Schema      |
              |                      |
              | canonical names      |
              | object identities    |
              | dependencies         |
              | validated references |
              +----------+-----------+
                         |
        +----------------+----------------+
        |                |                |
        v                v                v
     Printer           Diff           Consumers
                         |                |
                         v         +------+------+
                    Migration      |             |
                       Plan      Migrator     Hasql
                                      |
                                   Recycler
```

The separation between the **source AST** and the **canonical schema** is
particularly important.

The source AST answers:

```text
"What exactly did this SQL source say?"
```

The canonical schema answers:

```text
"What database structure does this DDL define?"
```

Those are related questions, but they are not the same question.

---

# Getting started

## Requirements

The current project uses:

```text
Stack resolver: LTS 20.11
GHC series:     9.2
Package:        SqlDdl-0.1.0.0
```

The current package also depends on:

```text
postgresql-syntax
headed-megaparsec
megaparsec
hasql
hasql-th
hasql-pool
postgresql-binary
aeson
yaml
optparse-applicative
```

Some of these dependencies come from the generic FUDD application template
and are not yet central to the DDL implementation.

---

## Clone

```bash
git clone git@github.com:whatsupfudd/sqlddl.git
cd sqlddl
```

---

## Build

The repository is currently an active development snapshot.

The normal build command is:

```bash
stack build
```

However, the current `main` branch contains unfinished implementation code
and should not yet be assumed to be build-clean.

Completing the current interpretation layer and establishing a CI build
should be considered part of the first stabilization milestone.

---

# Current command-line interface

The executable is currently named:

```text
SqlDdl
```

The CLI declares three commands:

```text
help
version
parse
```

Using the standard FUDD Stack invocation convention:

```bash
stack exec -- SqlDdl version
```

and:

```bash
stack exec -- SqlDdl parse \
  'create table person (id int, name varchar(100))'
```

The `parse` command currently performs approximately:

```text
input SQL
   |
   v
parseDdl
   |
   v
DdlStmt AST
   |
   v
Ddl.Interpret.convert
   |
   v
TableMap
   |
   v
Ddl.Printer
```

Because the interpretation and printer layers are incomplete, the CLI should
currently be treated as a parser-development tool rather than a stable
end-user interface.

---

## Configuration

The current generic application shell reads YAML configuration.

The implementation currently defines its default path as:

```text
~/.Configs/SqlDdl.yaml
```

The configuration can also be supplied using:

```text
--config
-c
```

or the environment variable:

```text
SqlDdlCONF
```

`SqlDdlHOME` is also read by the application shell but is not yet materially
used by the DDL implementation.

There is currently an inconsistency between the CLI help text and the
implemented default configuration path. This should be fixed during
stabilization.

---

# Current parser API

The principal parser entry point is currently:

```haskell
parseDdl
  :: Text
  -> Either String (NonEmpty DdlStmt)
```

from:

```haskell
Ddl.Parsers
```

For example:

```haskell
{-# LANGUAGE OverloadedStrings #-}

import Ddl.Parsers

example =
  parseDdl
    "create table person \
    \(id int, name varchar(80));"
```

The top-level AST is currently:

```haskell
data DdlStmt
  = CreateDS CreateStmt
  | AlterDS AlterStmt
```

Multiple statements can be separated by semicolons.

---

# Current DDL AST

## CREATE

The current `CreateStmt` distinguishes:

```haskell
data CreateStmt
  = CreateTable TableDef
  | CreateIndex IndexDef
  | CreateSchema SchemaDef
  | CreateSequence SequenceDef
```

This is a useful initial separation and should remain conceptually present
as the AST becomes more comprehensive.

---

## `CREATE TABLE`

The current table definition captures:

```text
table kind
IF NOT EXISTS
table name
column definitions
```

A table kind contains early support for:

```text
GLOBAL / LOCAL
TEMP / TEMPORARY
UNLOGGED
```

The current column representation is:

```haskell
CreateColumnItem
  identifier
  column specification
  optional constraint definition
```

---

## Current SQL types

The current AST only defines:

```haskell
IntCS
VarcharCS (Maybe Int)
```

corresponding approximately to:

```sql
int
integer
varchar
varchar(n)
```

This is one of the areas that requires substantial expansion.

PostgreSQL has a much richer type system, and the eventual schema model
should not reduce that richness prematurely.

---

## Column constraints

The parser already recognizes the beginnings of syntax for:

```text
NULL / NOT NULL
CHECK
DEFAULT
GENERATED
UNIQUE
PRIMARY KEY
REFERENCES
DEFERRABLE
INITIALLY ...
```

but most currently map to placeholder `TodoST` values.

Only parts such as `DEFAULT` retain meaningful expression information.

This means that:

> syntactic recognition should not presently be confused with implemented
> semantic modelling.

---

## `CREATE INDEX`

The parser currently recognizes an initial subset including:

```text
UNIQUE
CONCURRENTLY
IF NOT EXISTS
index name
ON
ONLY
```

but does not yet model the complete index definition.

The target model needs to include such concepts as:

```text
target relation
index method
indexed expressions
operator classes
ordering
NULL ordering
INCLUDE columns
predicate
storage parameters
tablespace
```

where relevant.

---

## `CREATE SCHEMA`

The current parser understands initial concepts including:

```text
IF NOT EXISTS
schema name
AUTHORIZATION
CURRENT_ROLE
CURRENT_USER
SESSION_USER
```

and contains preliminary support for nested schema elements.

---

## `CREATE SEQUENCE`

The current AST already represents several useful sequence concepts:

```text
name
AS type
increment
minimum
maximum
start
cache
cycle
owner
```

This should eventually become part of the resolved canonical schema rather
than remaining only a source statement.

---

## `ALTER TABLE`

The current AST is intentionally minimal:

```haskell
data AlterStmt
  = AlterTable Ident
```

The parser currently recognizes only:

```text
ALTER TABLE <name>
```

as structured information.

The source file contains PostgreSQL's much larger `ALTER TABLE` grammar as a
development reference, but the individual alteration actions are not yet
implemented.

This is a major required area because meaningful schema evolution depends
heavily on `ALTER`.

---

# Canonical schema model

The repository already contains the beginning of a second representation in:

```haskell
Ddl.Entities
```

with concepts such as:

```text
DefContext
Table
Column
Index
Sequence
Constraint
SqlType
```

The idea is correct: consumers usually should not need to inspect the exact
syntax of every `CREATE` and `ALTER` statement.

However, the present model is only a prototype.

A target canonical representation should evolve toward something
conceptually similar to:

```text
SchemaCatalog
 |
 +-- schemas
 |    |
 |    +-- tables
 |    |    |
 |    |    +-- columns
 |    |    +-- constraints
 |    |    +-- indexes
 |    |    `-- dependencies
 |    |
 |    +-- sequences
 |    +-- types/domains
 |    +-- views
 |    `-- other supported objects
 |
 `-- diagnostics / provenance
```

The canonical model should use strong identifiers and qualified names where
needed rather than relying only on plain `Text`.

---

## Do not conflate SQL types and Haskell types

The current prototype contains:

```haskell
data HkType
```

alongside `SqlType`.

That should not become the central design of SqlDdl.

SqlDdl's canonical responsibility is understanding the **SQL schema**.

For compile-time Hasql integration, the important type vocabulary is the SQL
/ Hasql typename vocabulary:

```text
int4
int8
text
uuid
timestamptz
...
```

not a new DDL syntax for Haskell types.

Application-specific Haskell codecs and result construction belong at the
Hasql boundary.

This separation prevents the schema model from becoming tied to one Haskell
record-generation strategy.

---

# Parsing versus interpretation

The existing code already hints at an important two-stage process:

```text
parse
  |
  v
DdlStmt
  |
  v
interpret
  |
  v
TableMap
```

The target system should generalize that into:

```text
source SQL
   |
   v
Source AST
   |
   v
statement interpretation
   |
   v
unresolved schema model
   |
   v
name/type/reference resolution
   |
   v
resolved canonical schema
```

This distinction matters because DDL can be procedural in nature.

For example:

```sql
CREATE TABLE customer (...);

ALTER TABLE customer
  ADD COLUMN email text;

CREATE INDEX customer_email_idx
  ON customer (email);
```

The final schema contains:

```text
customer
  id ...
  email text

customer_email_idx
  -> customer.email
```

even though those facts were distributed across three statements.

A schema interpreter therefore needs to **apply DDL operations in sequence**
rather than merely collect syntax nodes.

---

# Schema resolution and validation

Parsing tells us that the source is syntactically understandable.

Resolution answers questions such as:

```text
Which schema does this unqualified name refer to?

Does this referenced table exist?

Does this referenced column exist?

Does a foreign key reference compatible columns?

Does an index refer to valid columns?

Has this object already been defined?

Is a sequence owner valid?
```

The resolved schema should become the primary input for downstream tools.

---

## Target validation classes

Useful diagnostics should include at least:

```text
duplicate schema
duplicate relation
duplicate column
duplicate constraint
duplicate index

unknown relation
unknown column
unknown type
unknown sequence

invalid foreign-key target
foreign-key arity mismatch
foreign-key type mismatch

invalid sequence ownership
invalid index reference
invalid constraint reference

conflicting alteration
invalid object lifecycle
```

Diagnostics should contain source locations wherever the original DDL
provides them.

---

# SQL generation

SqlDdl should eventually support two distinct output modes.

## Source-preserving rendering

Given a source AST, retain as much original representation as possible.

This is important for:

```text
source rewriting
automated refactoring
legacy migration
small targeted edits
```

The goal is not necessarily byte-for-byte preservation in every mode, but
comments, identifiers, meaningful source spans, and untouched constructs
should not disappear unnecessarily.

---

## Canonical rendering

A canonical printer should produce deterministic PostgreSQL DDL from the
canonical schema.

For example:

```text
canonical schema
      |
      v
stable ordering
stable formatting
canonical type names
explicit constraints
      |
      v
canonical SQL
```

This is useful for:

```text
Git comparison
tests
generated schemas
migration verification
schema fingerprints
```

---

## Current printer

The current:

```haskell
Ddl.Printer
```

contains:

```haskell
showCompact
showIndiv
```

and a minimal type renderer for:

```text
int
varchar
varchar(n)
```

This is useful development scaffolding but should not yet be regarded as a
general DDL serializer.

---

# Schema comparison

One of SqlDdl's most important target capabilities is comparing two canonical
schema states.

```text
Schema A
   |
   | diff
   v
Schema B
```

should produce a typed change model rather than a text diff.

Conceptually:

```haskell
data SchemaChange
  = CreateTable ...
  | DropTable ...
  | RenameTable ...
  | AddColumn ...
  | DropColumn ...
  | RenameColumn ...
  | AlterColumnType ...
  | AlterColumnNullity ...
  | AlterColumnDefault ...
  | AddConstraint ...
  | DropConstraint ...
  | CreateIndex ...
  | DropIndex ...
  | AlterSequence ...
  | ...
```

This typed diff becomes the bridge between SqlDdl and Migrator.

---

## Semantic diff versus textual diff

These definitions:

```sql
CREATE TABLE a (
  id integer
);
```

and:

```sql
create table a
(
    id int
);
```

should normally be considered the same schema.

A source-control text diff sees many changes.

A schema diff should ideally see:

```text
no semantic change
```

Conversely:

```sql
amount integer
```

changing to:

```sql
amount bigint
```

may be only a few changed characters but can have important migration
consequences.

SqlDdl's canonical model enables semantic comparison.

---

# Migration planning

SqlDdl should describe **what changed**.

Migrator should decide **how that change is safely executed**.

A useful boundary is:

```text
SqlDdl
  Schema A
      +
  Schema B
      |
      v
  SchemaDiff
      |
      v
Migrator
  dependency ordering
  migration strategy
  data transformation
  safety checks
  execution
```

The two projects should remain separable.

SqlDdl should not gradually become a stateful production migration runner.

---

## Migration dependencies

Some schema changes impose ordering.

For example:

```text
create parent table
      |
      v
create child table
      |
      v
add foreign key
```

or:

```text
drop foreign key
      |
      v
drop referenced column
```

A schema-difference model should expose enough dependency information for
Migrator to derive an execution DAG.

---

## Destructive operations

Changes such as:

```text
DROP TABLE
DROP COLUMN
type narrowing
constraint strengthening
```

should be explicitly identifiable as potentially destructive.

They should never be silently hidden inside generated SQL.

---

## Renames

A textual comparison cannot reliably distinguish:

```text
drop old_name
add new_name
```

from:

```text
rename old_name -> new_name
```

Automatically guessing renames can destroy data when the guess is wrong.

The preferred architecture should therefore support explicit rename
information or reviewable migration decisions.

Heuristic rename candidates may be useful, but they should be represented as
candidates requiring confirmation rather than unquestioned facts.

---

## Data migrations

Some schema changes cannot be derived solely from DDL.

For example:

```text
split full_name into first_name + last_name

convert status integers into semantic enum values

move rows between tables

derive a new key from existing business data
```

SqlDdl can identify the structural change.

Migrator must allow an explicit data-transformation step to complete it.

---

# Schema history

Once schemas are represented canonically, Git history becomes a useful source
of data-model history.

Conceptually:

```text
Git commit A
     |
     v
DDL snapshot A
     |
     v
Schema A

Git commit B
     |
     v
DDL snapshot B
     |
     v
Schema B

Schema A --- diff ---> Schema B
```

Repeating this operation can create:

```text
schema lineage
object lineage
column lineage
migration candidates
change classification
```

This is particularly useful for understanding legacy systems where the
migration history itself may be incomplete or inconsistent.

Schema-history analysis is expected to be used by Migrator and may also
become valuable to Recycler.

---

# Hasql and Hasql-TH integration

A separate but important target is compile-time validation of embedded SQL.

FUDD already relies heavily on:

```text
Hasql
Hasql.TH
```

for typed PostgreSQL access.

Hasql.TH normally knows about types that are explicitly supplied through SQL
annotations such as:

```sql
$1::int4
```

and:

```sql
result_column::text
```

SqlDdl can provide something Hasql.TH does not otherwise possess:

> knowledge of the application's table definitions.

---

## Intended schema-context model

The intended design is conceptually similar to:

```haskell
schema =
  [ddl|
    CREATE TABLE project (
      uid       bigint PRIMARY KEY,
      label     text NOT NULL,
      owner_fk  bigint NOT NULL
    );
  |]
```

followed by SQL compilation that is evaluated in that schema context.

The precise final API belongs to the Hasql-TH integration work, but the
architecture should be equivalent to:

```text
DDL
 |
 v
SqlDdl parser
 |
 v
schema context
 |
 +-------------------------------+
 |                               |
 v                               v
embedded SELECT              embedded INSERT
embedded UPDATE              embedded DELETE
 |
 v
table / column / SQL-type verification
 |
 v
existing Hasql.TH type machinery
```

---

## What schema-aware validation can provide

With a known schema, embedded SQL can potentially validate:

```text
table existence
column existence
qualified column resolution
column SQL type
INSERT target columns
UPDATE target columns
RETURNING columns
simple SELECT projections
WHERE-column references
placeholder SQL types
```

For example:

```sql
SELECT uid, label
FROM project
WHERE owner_fk = $1
```

could infer that:

```text
uid      -> bigint
label    -> text
owner_fk -> bigint
$1       -> bigint
```

from the schema.

---

## Keep PostgreSQL/Hasql typenames authoritative

A key design constraint is:

> do not introduce a second Haskell-type language into DDL.

The existing Hasql approach already understands annotations such as:

```sql
::int4
::text
::uuid
```

Schema-aware inference should feed those same PostgreSQL typenames into the
existing Hasql.TH pipeline.

Conceptually:

```text
schema column
     |
     v
PostgreSQL typename
     |
     v
Hasql primitive type
     |
     v
existing Hasql.TH encoder/decoder construction
```

Explicit casts remain useful and should continue to act as explicit
overrides where appropriate.

---

## Strict ambiguity handling

Schema inference should make SQL safer, not more magical.

When a type or column cannot be established unambiguously:

```text
do not guess
```

The compile-time tooling should report a structured error and require the
developer to make the SQL explicit.

---

# Recycler integration

Recycler is FUDD's legacy-system understanding and modernisation environment.

Database structure is a major part of many legacy applications.

SqlDdl can provide Recycler with:

```text
legacy DDL
    |
    v
canonical schema
    |
    +-- entity relationships
    +-- keys
    +-- constraints
    +-- indexes
    +-- type information
    +-- dependency graph
    |
    v
legacy-system model
```

That information can be combined with Recycler's source-code understanding.

For example:

```text
PHP / Ruby / Java / Haskell code
              +
           SQL schema
              |
              v
     application model
```

is much more informative than examining either source independently.

---

## Progressive legacy replacement

For modernisation projects, a target workflow is:

```text
legacy schema
     |
     v
SqlDdl canonical model
     |
     v
proposed target schema
     |
     v
semantic schema diff
     |
     v
Migrator plan
     |
     v
compatibility tests
     |
     v
progressive replacement
```

SqlDdl should therefore prioritize accurate representation and equivalence
testing over clever but lossy rewriting.

---

# Source traceability

The canonical schema should not erase where information came from.

A future schema object should be able to retain or reference provenance such
as:

```text
source file
statement
source span
original identifier spelling
original type spelling
comments where relevant
Git revision
parser diagnostics
```

A conceptual object could therefore look like:

```text
Column
 |
 +-- canonical identity
 +-- canonical name
 +-- canonical SQL type
 +-- nullability
 +-- default
 +-- constraints
 |
 `-- provenance
       |
       +-- source file
       +-- source span
       +-- statement ID
       `-- revision
```

This matters for both Recycler and migration review.

A generated change should eventually be able to explain:

```text
"this migration step exists because column X changed between these two
source-backed schema definitions"
```

rather than presenting an opaque generated command.

---

# Proposed target API

The exact API is expected to evolve, but a useful architectural direction is
to separate the major stages explicitly.

For example:

```haskell
parseDdlSource
  :: ParseConfig
  -> SourceName
  -> Text
  -> Either [Diagnostic] DdlDocument
```

followed by:

```haskell
interpretSchema
  :: InterpretConfig
  -> DdlDocument
  -> Either [Diagnostic] UnresolvedSchema
```

then:

```haskell
resolveSchema
  :: ResolveConfig
  -> UnresolvedSchema
  -> Either [Diagnostic] Schema
```

Comparison can then operate on schemas rather than parser syntax:

```haskell
diffSchemas
  :: DiffConfig
  -> Schema
  -> Schema
  -> SchemaDiff
```

and SQL generation can be kept independent:

```haskell
renderCanonicalSchema
  :: RenderConfig
  -> Schema
  -> Text
```

The purpose of this split is more important than the exact names.

Each stage should have a clear contract:

```text
parse       syntax
interpret   effects of DDL statements
resolve     names/types/references
validate    invariants
diff        semantic change
render      SQL representation
```

---

# Module map

## Current parser and AST

| Module | Current role |
| --- | --- |
| `Ddl.Parsers` | Top-level DDL parser and `DdlStmt` |
| `Ddl.CreateParser` | `CREATE` statement parsers |
| `Ddl.AlterParser` | Early `ALTER` parser |
| `Ddl.Ast.Create` | AST for CREATE statements |
| `Ddl.Ast.Alter` | AST for ALTER statements |
| `Ddl.Extras` | Shared headed-Megaparsec parsing helpers |

## Current interpretation

| Module | Current role |
| --- | --- |
| `Ddl.Entities` | Prototype canonical/interpreted entities |
| `Ddl.Interpret` | Partial AST-to-table-model conversion |
| `Ddl.Printer` | Early SQL rendering |

## Command-line application

| Module | Current role |
| --- | --- |
| `MainLogic` | Command dispatch |
| `Commands.Parse` | Parse/interpret/print development command |
| `Commands.Help` | Help command |
| `Commands.Version` | Version information |
| `Options.Cli` | CLI parser |
| `Options.ConfFile` | YAML configuration |
| `Options.Runtime` | Effective runtime options |
| `Options` | Configuration merging |

## Database-template infrastructure

| Module | Current role |
| --- | --- |
| `DB.Connect` | Generic Hasql pool helper |
| `DB.Opers` | Example/placeholder Hasql operations |

The DB modules are currently application-template infrastructure rather than
part of the core SqlDdl design.

The long-term SqlDdl library itself should not require an active database in
order to parse or compare schemas.

---

# Development roadmap

The gap between the current prototype and the intended architecture is
substantial enough that development should proceed in explicit stages.

---

## Phase 0 — Stabilize the existing repository

Before broadening SQL coverage:

```text
make main build cleanly
establish CI
implement real tests
remove partial record construction
remove accidental runtime bottoms
clean package metadata
clarify CLI/configuration behaviour
```

The parser core should become reliably testable as a library before more
syntax is added.

---

## Phase 1 — Source-aware PostgreSQL DDL front end

Build a trustworthy source representation.

Priorities:

```text
CREATE TABLE
ALTER TABLE
CREATE/DROP INDEX
CREATE/DROP SEQUENCE
CREATE/DROP SCHEMA
DROP TABLE
```

followed progressively by additional PostgreSQL objects required by FUDD
projects.

Represent:

```text
qualified identifiers
PostgreSQL type names
expressions
column constraints
table constraints
foreign keys
defaults
generated columns
identity columns
indexes
sequences
```

Add source locations and structured diagnostics from the beginning.

---

## Phase 2 — Canonical schema model

Create a representation independent of statement order and formatting.

Core objects should include:

```text
catalog
schema
relation/table
column
SQL type reference
primary key
foreign key
unique constraint
check constraint
default
index
sequence
```

Separate:

```text
unresolved references
```

from:

```text
resolved object identities
```

rather than storing every relationship as plain text.

---

## Phase 3 — Schema interpretation and resolution

Implement sequential DDL application:

```text
CREATE
ALTER
DROP
...
```

and resolve:

```text
qualified names
schema names
column names
type aliases
foreign-key targets
sequence owners
index targets
```

Produce structured diagnostics for invalid state transitions.

---

## Phase 4 — Canonical printer and round-trip testing

Implement:

```text
source-aware rendering
canonical deterministic rendering
```

and establish strong tests around:

```text
parse -> print -> parse
```

and:

```text
source -> canonical schema
canonical SQL -> canonical schema
```

equivalence.

---

## Phase 5 — Semantic schema diff

Implement typed comparison between two resolved schemas.

Initial operations should cover:

```text
create/drop table
add/drop column
change SQL type
change nullability
change default
add/drop key
add/drop foreign key
add/drop constraint
create/drop index
sequence changes
```

Then add explicit rename modelling.

---

## Phase 6 — Migrator integration

Turn:

```text
SchemaDiff
```

into an input contract for Migrator.

Add:

```text
dependency information
destructive-change classification
preconditions
postconditions
review requirements
```

Migrator can then add execution policy, explicit data migration, transaction
strategy, and rollback handling.

---

## Phase 7 — Schema history

Add tooling to compare schema snapshots from Git history.

Derive:

```text
schema evolution
object lineage
column lineage
change history
migration reconstruction
```

without treating textual changes as semantic changes.

---

## Phase 8 — Hasql-TH schema context

Expose the canonical schema model to compile-time tooling.

The intended capability is:

```text
embedded DDL
      |
      v
SqlDdl schema
      |
      v
embedded SQL
      |
      v
compile-time table/column/type validation
```

Preserve the existing Hasql typename machinery rather than adding Haskell
types to SQL syntax.

---

## Phase 9 — Recycler integration

Expose stable schema-analysis APIs for legacy-system ingestion.

Recycler should be able to use SqlDdl for:

```text
schema inventory
relationship extraction
schema comparison
modernisation planning
compatibility validation
```

without depending on SqlDdl's CLI.

---

# Testing strategy

SqlDdl needs a much stronger test suite than most ordinary parsers because
downstream migration tools will eventually make potentially destructive
decisions from its output.

The current test target is only a placeholder.

Testing should become a core part of the architecture.

---

## Parser fixtures

Maintain representative PostgreSQL fixtures for:

```text
tables
constraints
indexes
sequences
schemas
ALTER operations
quoted identifiers
qualified names
complex defaults
generated columns
foreign keys
```

Include both:

```text
expected-success
```

and:

```text
expected-failure
```

cases.

---

## PostgreSQL-derived corpus

Real PostgreSQL schema dumps are particularly valuable.

Fixtures should include output resembling:

```bash
pg_dump --schema-only
```

from several real FUDD projects.

This exercises syntax that handcrafted examples tend to miss.

---

## Golden AST tests

For each fixture:

```text
SQL
 |
 v
AST
```

should be compared with an approved representation.

This makes parser changes explicit during review.

---

## Canonical-model tests

Different source spellings should converge to equivalent schema models where
PostgreSQL semantics are equivalent.

For example:

```sql
integer
```

and:

```sql
int4
```

may need appropriate canonical type relationships while still preserving
their source spelling when provenance matters.

---

## Round-trip tests

Use:

```text
parse
 ->
render
 ->
parse
```

to establish stability.

Source-preserving and canonical rendering should have separate expectations.

---

## Property tests

Property testing is useful for:

```text
identifier handling
qualified-name normalization
schema-map invariants
diff symmetry properties
diff identity
migration dependency ordering
printer/parser round trips
```

A fundamental property should be:

```text
diff schema schema == noChanges
```

---

## Diff tests

Maintain explicit fixtures for:

```text
table creation
table deletion
column addition
column deletion
rename
type change
constraint change
foreign-key change
index change
sequence change
```

and combinations of dependent changes.

---

## Migration proof cases

Migrator integration should include more difficult cases such as:

```text
rename
table split
table merge
data transformation
type conversion
rollback
```

These expose the difference between structural schema comparison and real
migration planning.

---

# Design principles

## PostgreSQL first

SqlDdl currently uses PostgreSQL syntax infrastructure and FUDD's database
stack is predominantly PostgreSQL/Hasql.

The immediate objective should therefore be excellent PostgreSQL support
rather than superficial support for many SQL dialects.

The architecture should avoid unnecessary barriers to future dialects, but
premature cross-dialect abstraction should not weaken PostgreSQL fidelity.

---

## Preserve information before normalizing it

The source layer should retain enough information for:

```text
diagnostics
rewriting
migration review
traceability
```

Normalization should be an explicit transformation rather than an
irreversible side effect of parsing.

---

## Use typed representations

Important concepts should have dedicated types:

```text
RelationName
ColumnName
TypeName
ConstraintName
IndexName
SequenceName
```

or equivalent qualified identifiers.

A canonical schema should not become:

```haskell
Map Text (Map Text Text)
```

where every invariant exists only in developer convention.

---

## Keep syntax, semantics, and execution separate

SqlDdl should distinguish:

```text
syntax:
    what SQL was written

schema semantics:
    what structure that SQL defines

migration:
    how to transform one live state into another
```

This separation lets SqlDdl remain useful outside Migrator.

---

## Fail on unresolved ambiguity

Schema tools can destroy data.

When a relationship cannot be resolved safely, explicit failure is preferable
to a clever guess.

This applies especially to:

```text
renames
type conversions
foreign-key targets
search-path ambiguity
migration ordering
```

---

## Make destructive changes visible

Dropping or narrowing data should always survive into the typed change model
as an explicit operation.

No normalization or migration-generation stage should hide the destructive
nature of the change.

---

## Keep the core library pure

Most SqlDdl functionality should have interfaces conceptually like:

```haskell
Text -> Either Errors Ast
Ast -> Either Errors Schema
Schema -> Schema -> SchemaDiff
Schema -> Text
```

Database connections, filesystem scanning, Git operations, and migration
execution should remain outer-layer concerns.

This makes the core easier to test, reuse, and reason about.

---

## Maintain provenance

A schema element should retain a path back to the evidence from which it was
derived.

That principle is especially important when SqlDdl feeds:

```text
Recycler
Migrator
AI-assisted development tools
compile-time validators
```

because a human developer should be able to inspect why a conclusion was
reached.

---

# Current limitations

The current implementation has several limitations that should be understood
before using it as a dependency.

## The repository is an early development snapshot

The current code contains unfinished construction paths and should not yet
be treated as a released build.

---

## SQL type coverage is extremely small

Only:

```text
int
integer
varchar
varchar(n)
```

are represented by the current custom column AST.

The source file already records PostgreSQL's much larger type vocabulary as
a development reference, but it is not implemented.

---

## Constraints are mostly placeholders

Several constraint parsers recognize syntax but return:

```haskell
TodoST
```

rather than meaningful typed representations.

---

## `ALTER TABLE` is only a skeleton

The AST retains the table name but not the actual alteration actions.

---

## Interpretation only targets tables

The current interpreter is designed around creation of a `TableMap`.

Other parsed CREATE objects are not yet safely interpreted.

---

## ALTER statements are not applied

They are returned as "left over" information rather than modifying the
canonical table state.

---

## The prototype canonical model is incomplete

`Ddl.Entities` currently contains only very small representations of:

```text
tables
columns
indexes
sequences
constraints
SQL types
```

and does not yet model complete PostgreSQL semantics.

---

## Haskell-type information is experimental

`HkType` exists in the prototype model but should not be interpreted as a
commitment to automatic DDL-to-Haskell record generation.

The preferred schema boundary is PostgreSQL types.

---

## SQL printing is minimal

The printer currently understands only the very small interpreted type
subset.

---

## Database code is mostly template infrastructure

`DB.Opers` currently contains example/commented Hasql code rather than
SqlDdl persistence functionality.

The SqlDdl core should not require its own database.

---

## Configuration infrastructure is inherited from the generic application template

Several configuration fields are not currently needed by parser operation.

There is also an inconsistency between the configured default path and the
path described by CLI help.

---

## Test suite is not implemented

The current test executable simply reports:

```text
Test suite not yet implemented
```

This is the most important engineering weakness to address before using
SqlDdl for migration generation.

---

# Repository housekeeping

Several metadata fields still refer to an older repository location:

```text
hugodro/SqlDdl
```

These should be updated to:

```text
whatsupfudd/sqlddl
```

in:

```text
package.yaml
generated Cabal metadata
homepage
bug-report URL
source-repository location
README links
```

The current package metadata also still contains earlier ownership
information that should be reviewed against current FUDD conventions.

---

## Changelog

The current changelog contains only the generated initial skeleton.

As development restarts, it should begin recording milestones such as:

```text
parser stabilization
canonical schema model
ALTER support
schema resolver
canonical printer
schema diff
Migrator API
Hasql schema API
Recycler API
```

---

## Package version

The current:

```text
0.1.0.0
```

version appropriately indicates an unstable early API.

The project should remain in the `0.x` series while foundational public
types such as:

```text
DDL AST
canonical schema
diagnostics
schema diff
```

continue to change substantially.

---

# Long-term position

SqlDdl should ultimately become the common typed representation of
relational schema information inside FUDD.

Its role is intentionally narrower than a database IDE and broader than a
DDL parser.

```text
                      SQL / pg_dump
                           |
                           v
                     +-----------+
                     |  SqlDdl   |
                     +-----------+
                       /    |    \
                      /     |     \
                     v      v      v
                Migrator  Hasql  Recycler
                    |       |       |
                    v       v       v
                schema   compile- legacy
                change   time     system
                control  safety   analysis
```

The value of the project comes from having **one trustworthy schema model**
at the center of those workflows.

That shared representation allows:

- parser improvements to benefit every consumer;
- migrations to be based on semantic rather than textual differences;
- embedded SQL to be checked against the same schema used by migration
  tooling;
- legacy systems to be analysed with the same model used for their target
  replacements;
- schema history to become inspectable structured data; and
- future AI-assisted transformations to operate on typed, source-backed
  evidence rather than free-form SQL strings.

The immediate development objective is therefore not to add many commands.

It is to establish a small, rigorous chain:

```text
PostgreSQL DDL
    ->
source AST
    ->
canonical schema
    ->
resolution + validation
    ->
deterministic rendering
```

Once that foundation is trustworthy, schema diffing, Migrator,
Hasql-TH verification, Recycler integration, and higher-level automated
schema engineering can be built on top of it safely.

---

# License

The package metadata declares SqlDdl under the **BSD-3-Clause** license.

See the repository's `LICENSE` file for the authoritative licensing terms.