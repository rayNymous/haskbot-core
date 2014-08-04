{-# LANGUAGE OverloadedStrings #-}

-- | This provides a simple representation of the request data for a Slack
--   /incoming/ integration- the means via which HaskbotM replies to Slack.
--   Currently only simple text replies are supported, but this will be expanded
--   to support fully-slack-formatted messages in the future.
module Network.Haskbot.Incoming
( Incoming (..)
, addToSendQueue
, sendFromQueue
) where

import Control.Concurrent (threadDelay)
import Control.Concurrent.STM (atomically)
import Control.Concurrent.STM.TVar (modifyTVar', readTVar)
import Control.Monad (forever)
import Control.Monad.Reader (MonadIO, asks, liftIO)
import Data.Aeson (ToJSON, (.=), encode, object, toJSON)
import Data.ByteString.Lazy (ByteString)
import Data.Text (Text)
import Network.Haskbot.Config (incQueue, incUrl, netConn)
import Network.Haskbot.Internal.Monad (ConfigT)
import Network.Haskbot.Internal.Request (jsonContentType)
import Network.Haskbot.Types (Channel, getAddress)
import Network.HTTP.Conduit -- basically everything
import Network.HTTP.Types (methodPost, status200)

data Incoming =
  Incoming { incChan :: !Channel
           -- ^ the channel to send the reply
           , incText :: {-# UNPACK #-} !Text
           -- ^ the text of the reply
           } deriving (Eq, Show)

instance ToJSON Incoming where
  toJSON inc = object [ "channel" .= getAddress (incChan inc)
                      , "text"    .= incText inc
                      ]

-- constants

timeBetweenSends :: Int
timeBetweenSends = 1000000 -- Slack rate limit

-- internal functions

addToSendQueue :: (MonadIO m) => Incoming -> ConfigT m ()
addToSendQueue inc = enqueueMsg . encode $ toJSON inc

sendFromQueue :: (MonadIO m) => ConfigT m ()
sendFromQueue = forever $ dequeueMsg >>= sendMsg >> wait

-- private functions

incRequest :: (MonadIO m) => ConfigT m Request
incRequest = do
    url <- asks incUrl
    initRequest <- liftIO $ parseUrl url
    return $ initRequest
      { method            = methodPost
      , rawBody           = True
      , requestHeaders    = [jsonContentType]
      }

-- TODO:
-- 1. If the message queue extends beyond a certain count, Slack is
--    probably down and we should halt adding to the queue until it returns.
-- 2. Log any failed responses

enqueueMsg :: (MonadIO m) => ByteString -> ConfigT m ()
enqueueMsg msg = do
    queue <- asks incQueue
    liftIO . atomically $ modifyTVar' queue $ \q -> q ++ [msg]

dequeueMsg :: (MonadIO m) => ConfigT m (Maybe ByteString)
dequeueMsg = do
    queue <- asks incQueue
    liftIO . atomically $ do
        msgs <- readTVar queue
        case msgs of
          (m:ms) -> do
            modifyTVar' queue $ \q -> tail q
            return $ Just m
          _ -> return Nothing

sendMsg :: (MonadIO m) => Maybe ByteString -> ConfigT m ()
sendMsg (Just msg) = do
    conn <- asks netConn
    template <- incRequest
    let newRequest = template { requestBody = RequestBodyLBS msg }
    liftIO (httpLbs newRequest conn) >>= handleResp msg
sendMsg _ = return ()

handleResp :: (MonadIO m) => ByteString -> Response a -> ConfigT m ()
handleResp msg resp
    | allGood   = return ()
    | otherwise = enqueueMsg msg
  where
    allGood = responseStatus resp == status200

wait :: (MonadIO m) => ConfigT m ()
wait = liftIO $ threadDelay timeBetweenSends
