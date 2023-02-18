module Options.Runtime (defaultRun, RunOptions (..), DbConfig (..)) where
-- import Data.Int (Int)

import Data.Text (Text)

import DB.Connect (DbConfig (..), defaultDbConf)


data RunOptions = RunOptions {
    debug :: Int
    , db :: DbConfig
    -- HERE: Add additional vars for providing runtime parameters:
    -- Eg: , root :: Text
  }
  deriving (Show)

defaultRun :: RunOptions
defaultRun =
  RunOptions {
    debug = 0
    -- HERE: Use if accessing the DB: , db = defaultDbConf
   -- HERE: Set default value for additional runtime parameters:  , root = "/tmp"
  }
