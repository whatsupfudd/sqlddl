module Options  (
  module Options.Cli
  , module Options.ConfFile
  , module Options.Runtime
  , mergeOptions
 )
where

import qualified Data.Text as DT
import qualified Data.Text.Encoding as DT

import Options.Cli
import Options.ConfFile
import Options.Runtime


mergeOptions :: CliOptions -> FileOptions -> EnvOptions -> RunOptions
mergeOptions cli file env =
  -- TODO: put proper priority filling of values for the Runtime Options.
  let
    defO = defaultRun
    -- Update from config file:
    fileO =
      let
        dbgO = case file.debug of
          Nothing -> defO
          Just aVal -> defO { debug = aVal } :: RunOptions
        dbO = case file.db of
            Nothing -> dbgO
            Just aVal ->
              let
                portO = case aVal.port of
                  Nothing -> dbgO.db
                  Just anInt -> dbgO.db { port = fromIntegral anInt } :: DbConfig
                hostO = case aVal.host of
                  Nothing -> portO
                  Just aStr -> portO { host = DT.encodeUtf8 . DT.pack $ aStr } :: DbConfig
                userO = case aVal.user of
                  Nothing -> hostO
                  Just aStr -> hostO { user = DT.encodeUtf8 . DT.pack $ aStr } :: DbConfig
                pwdO =  case aVal.passwd of
                  Nothing -> userO
                  Just aStr -> userO { passwd = DT.encodeUtf8 . DT.pack $ aStr } :: DbConfig
                dbaseO =  case aVal.dbase of
                  Nothing -> pwdO
                  Just aStr -> pwdO { dbase = DT.encodeUtf8 . DT.pack $ aStr } :: DbConfig
              in
              dbgO { db = dbaseO } :: RunOptions
        {- HERE: add additional configurations:
        Eg: rootO = case file.rootDir of
          Nothing -> dbO
          Just aVal -> dbO { root = DT.pack aVal } :: RunOptions
        -}
      in
      dbO
    -- TODO: update from CLI options
    cliO = case cli.debug of
      Nothing -> fileO
      Just aVal -> fileO { debug = aVal } :: RunOptions
    -- TODO: update from ENV options
    envO = cliO
  in 
  envO
