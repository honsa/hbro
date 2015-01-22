{-# LANGUAGE ConstraintKinds     #-}
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE NoImplicitPrelude   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies        #-}
module Hbro.Core (
-- * Types
      CaseSensitivity(..)
    , Direction(..)
    , Wrap(..)
    , ZoomDirection(..)
-- * Getters
    , getCurrentURI
    , getFaviconURI
    , getFavicon
    , getLoadProgress
    , getPageTitle
-- * Browsing
    , goHome
    , load
    , reload
    , reloadBypassCache
    , stopLoading
    , goBack
    , goForward
-- * Other
    , printPage
    , searchText
    , searchText_
    , quit
    , executeJSFile
    ) where

-- {{{ Imports
import           Graphics.UI.Gtk.WebKit.Lifted.WebView

import           Hbro.Config                           as Config
import           Hbro.Error
-- import           Hbro.Gui                              as Gui
import           Hbro.Gui.MainView
import           Hbro.Logger                           hiding (initialize)
import           Hbro.Prelude                          as H

import           Graphics.UI.Gtk.Gdk.Pixbuf            (Pixbuf)
import           Graphics.UI.Gtk.General.General
import           Graphics.UI.Gtk.WebKit.WebDataSource
import           Graphics.UI.Gtk.WebKit.WebFrame

import           Network.URI.Monadic
-- }}}

-- {{{ Types
data CaseSensitivity = CaseSensitive | CaseInsensitive

instance ToBool CaseSensitivity where
    toBool CaseSensitive   = True
    toBool CaseInsensitive = False

data Direction = Forward | Backward

instance ToBool Direction where
    toBool Forward  = True
    toBool Backward = False

data Wrap = Wrap | NoWrap

instance ToBool Wrap where
    toBool Wrap   = True
    toBool NoWrap = False

data ZoomDirection = In | Out
-- }}}

-- {{{ Getters
getCurrentURI :: (MonadIO m, MainViewReader m, MonadError Text m) => m URI
getCurrentURI = webViewGetUri =<< getWebView

getFaviconURI :: (MonadIO m, MainViewReader m, MonadError Text m) => m URI
getFaviconURI = webViewGetIconUri =<< getWebView

getFavicon :: (MonadIO m, MainViewReader m, MonadError Text m) => Int -> Int -> m Pixbuf
getFavicon w h = (\v -> webViewTryGetFaviconPixbuf v w h) =<< getWebView

getLoadProgress :: (MonadIO m, MainViewReader m) => m Double
getLoadProgress = gSync . webViewGetProgress =<< getWebView

getPageTitle :: (MonadIO m, MainViewReader m, MonadError Text m) => m Text
getPageTitle = webViewGetTitle =<< getWebView
-- }}}

-- {{{ Browsing
goHome :: (MonadIO m, MainViewReader m, ConfigReader m, MonadError Text m) => m ()
goHome = load =<< Config.get homePageL

load :: (MonadIO m, MainViewReader m, MonadError Text m) => URI -> m ()
load uri = do
    debugM $ "Loading URI: " ++ tshow uri
    -- void . logErrors $ do
    --     currentURI <- getURI
    --     guard (currentURI /= uri')
    --     Browser.advance currentURI

    -- load' uri'
    webview <- getWebView
    gSync . webViewLoadUri webview $ show uri'

  where
    uri' = case uriScheme uri of
             [] -> uri { uriScheme = "http://" }
             _  -> uri
    -- baseOf uri = uri {
        -- uriPath = (++ "/") . join "/" . Prelude.init . split "/" $ uriPath uri
    -- }


-- load' :: (MonadBaseControl IO m, MonadReader GUI m, HasHTTPClient t, MonadError Text m) => URI -> m ()
-- load' uri = do
--     page <- Client.retrieve uri
--     -- render page =<< Client.getURI
--     render page uri


reload, goBack, goForward :: (MonadIO m, MainViewReader m, MonadError Text m) => m ()
-- reload    = load  =<< Client.getURI
-- goBack    = load' =<< Browser.stepBackward =<< getURI
-- goForward = load' =<< Browser.stepForward =<< getURI
reload    = gAsync . webViewReload    =<< getWebView
goBack    = gAsync . webViewGoBack    =<< getWebView
goForward = gAsync . webViewGoForward =<< getWebView

reloadBypassCache, stopLoading :: (MonadIO m, MainViewReader m) => m ()
reloadBypassCache = getWebView >>= gAsync . webViewReloadBypassCache >> debugM "Reloading without cache."
stopLoading = getWebView >>= gAsync . webViewStopLoading >> debugM "Stopped loading"
-- }}}


-- {{{
searchText :: (MonadIO m, MainViewReader m) => CaseSensitivity -> Direction -> Wrap -> Text -> m Bool
searchText s d w text = do
    debugM $ "Searching text: " ++ text
    v <- getWebView
    gSync $ webViewSearchText v text (toBool s) (toBool d) (toBool w)

searchText_ :: (MonadIO m, Functor m, MainViewReader m) => CaseSensitivity -> Direction -> Wrap -> Text -> m ()
searchText_ s d w text = void $ searchText s d w text

printPage :: (MonadIO m, MainViewReader m) => m ()
printPage = gAsync . webFramePrint =<< gSync . webViewGetMainFrame =<< getWebView
-- }}}

-- | Terminate the program.
quit :: (MonadIO m) => m ()
quit = gAsync mainQuit


-- {{{ Misc
-- | Execute a javascript file on current webpage.
executeJSFile :: (MonadIO m) => FilePath -> WebView -> m ()
executeJSFile filePath webView' = do
    debugM $ "Executing Javascript file: " ++ fpToText filePath
    script <- readFile filePath
    let script' = asText . unwords . map (++ "\n") . lines $ script

    gAsync $ webViewExecuteScript webView' script'
-- }}}

-- | Save current web page to a file,
-- along with all its resources in a separated directory.
-- Doesn't work for now, because web_resource_get_data's binding is missing...
_savePage :: Text -> WebView -> IO ()
_savePage _path webView' = do
    frame         <- webViewGetMainFrame webView'
    dataSource    <- webFrameGetDataSource frame
    _mainResource <- webDataSourceGetMainResource dataSource
    _subResources <- webDataSourceGetSubresources dataSource
    return ()
