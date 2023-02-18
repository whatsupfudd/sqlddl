{-# LANGUAGE TypeFamilies #-}
module Ddl.Extras where

import Control.Applicative (many)

import Data.List.NonEmpty (NonEmpty (..))

import qualified Text.Megaparsec as M
import qualified Text.Megaparsec.Char as M
import qualified Text.Megaparsec.Char.Lexer as ML

import qualified HeadedMegaparsec as HM
import qualified PostgresqlSyntax.Parsing as P


-- From PostgresqlSyntax.Extras.HeadedMegaparsec
space1 :: (Ord err, M.Stream strm, M.Token strm ~ Char) => HM.HeadedParsec err strm ()
space1 = HM.parse M.space1

space :: (Ord err, M.Stream strm, M.Token strm ~ Char) => HM.HeadedParsec err strm ()
space = HM.parse M.space

char :: (Ord err, M.Stream strm, M.Token strm ~ Char) => Char -> HM.HeadedParsec err strm Char
char a = HM.parse (M.char a)


-- redundant: , M.Token strm ~ Char
sep1 :: (Ord err, M.Stream strm) => HM.HeadedParsec err strm separtor -> HM.HeadedParsec err strm a -> HM.HeadedParsec err strm (NonEmpty a)
sep1 _separator _parser = do
  _head <- _parser
  HM.endHead
  _tail <- many $ _separator *> _parser
  return (_head :| _tail)


semicolonSeparator :: P.Parser ()
semicolonSeparator = space *> char ';' *> HM.endHead *> space

