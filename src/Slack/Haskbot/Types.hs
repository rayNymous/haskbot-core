{-|
Module      : Slack.Haskbot.Types
Description : Wrappers for Slack API data types
Copyright   : (c) Jonathan Childress 2014
License     : MIT
Maintainer  : jon@childr.es
Stability   : experimental
Portability : POSIX

This provides wrappers for the various types of data supplied by the Slack API,
so that any processing of the API data remains type-safe. No constructors are
directly exported to allow for flexibility with the currently-beta Slack API.
-}

module Slack.Haskbot.Types
(
-- * Slack types
-- ** Token
  Token
, getToken
, setToken
-- ** Team ID
, TeamID
, getTeamID
, setTeamID
-- ** Channel ID
, ChannelID
, getChanID
, setChanID
-- ** Channel name
, ChannelName
, getChanName
, getPoundChan
, setChanName
-- ** User ID
, UserID
, getUserID
, setUserID
-- ** User name
, UserName
, getUserName
, getAtUserName
, setUserName
-- ** Command
, Command
, getCommand
, getSlashCom
, setCommand
-- * Native types
-- ** Channel
, Channel (..)
, getAddress
) where

import Data.Text (Text, append, singleton)
import Slack.Haskbot.Internal.Types (prefixedBy)

prefixChan, prefixCom, prefixUser :: Char
prefixChan = '#'
prefixCom  = '/'
prefixUser = '@'

newtype Token
  = Token { getToken :: Text -- ^ get the text of a token
          } deriving (Eq, Show)

-- | make a token of the given text
setToken :: Text -> Token
setToken = Token

newtype TeamID
  = TeamID { getTeamID :: Text -- ^ get the text value of a team ID
           } deriving (Eq, Show)

-- | make a team ID of the given text value
setTeamID :: Text -> TeamID
setTeamID = TeamID

newtype ChannelID
  = ChannelID { getChanID :: Text -- ^ get the text value of a channel ID
              } deriving (Eq, Show)

-- | make a channel ID of the given text value
setChanID :: Text -> ChannelID
setChanID = ChannelID

newtype ChannelName
  = ChannelName { getChanName :: Text -- ^ get the text value of a channel name
                } deriving (Eq, Show)

-- | get the text value of a channel name, prefixed with a @#@
getPoundChan :: ChannelName -> Text
getPoundChan = append (singleton prefixChan) . getChanName

-- | make a channel name of the given text value
setChanName :: Text -> ChannelName
setChanName = prefixedBy prefixChan ChannelName

newtype UserID
  = UserID { getUserID :: Text -- ^ get the text value of a user ID
           } deriving (Eq, Show)

-- | make a user ID of the given text value
setUserID :: Text -> UserID
setUserID = UserID

newtype UserName
  = UserName { getUserName :: Text -- ^ get the text value of a username
             } deriving (Eq, Show)

-- | get the text value of a username prefixed with a @\@@
getAtUserName :: UserName -> Text
getAtUserName = append (singleton prefixUser) . getUserName

-- | make a username of given text value
setUserName :: Text -> UserName
setUserName = prefixedBy prefixUser UserName

newtype Command
  = Command { getCommand :: Text -- ^ get the text name of a command
            } deriving (Eq, Show)

-- | get the text name of a command prefixed with a @\/@
getSlashCom :: Command -> Text
getSlashCom = append (singleton prefixCom) . getCommand

-- | make a command with the given name
setCommand :: Text -> Command
setCommand = prefixedBy prefixCom Command

-- | Slack channels are either regular channels or direct messages to users
data Channel = DirectMsg {-# UNPACK #-} !UserName
             | Channel   {-# UNPACK #-} !ChannelName
             deriving (Eq, Show)

-- | Get the text representation of a channel, with the appropriate prefix
-- required by Slack
getAddress :: Channel -> Text
getAddress (DirectMsg un) = getAtUserName un
getAddress (Channel ch)   = getPoundChan ch
