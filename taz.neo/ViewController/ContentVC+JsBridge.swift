//
//  ContentVC+JsBridge.swift
//  taz.neo
//
//  Created by Ringo Müller on 08.05.26.
//  Copyright © 2026 taz. All rights reserved.
//

import UIKit
import WebKit
import NorthLib

/// Instructions
/// add function here in tazApiJsBridgeContent to use it in js
/// maybe implement native functions here in **Bridge native Part**
/// Add the JS Bridge Part (JS Call native functions) in **setupBridge() in ContentVC**
extension ContentVC {
  /// Write tazApi.js to resource directory
  public func writeTazApiJs() {
    setupBridge()
    tazApiJs.string = JSBridgeObject.js + "\n\n" + tazApiJsBridgeContent + "\n"
  }
}

//MARK: - Bridge native Part
extension ContentVC {
  func play(msid: String, audioFileName: String){
    guard let currentArt = issue.allArticles.first(where: {$0.serverId == Int64(msid)}) else {
      return
    }
    
    guard currentArt.audioItem?.file?.fileName == audioFileName else {
      log("audio filename mismatch for content at Index: \(index) to play id: \(msid) file: \(audioFileName)")
      return
    }

    if ArticlePlayer.singleton.currentContent?.audioItem?.file?.name == audioFileName.lastPathComponent {
      ArticlePlayer.singleton.toggle(origin: .appUi)
      return
    }
    
    ArticlePlayer.singleton.play(issue: issue,
                                 startFromArticle: currentArt,
                                 enqueueType: .replaceCurrent,
                                 loadIssueIfNeeded: !issue.isBookmarkIssue)
  }
}
//MARK: - JS Bridge Content (injected JS String)
extension ContentVC {
  fileprivate var tazApiJsBridgeContent : String {
        """
        var tazApi = new NativeBridge("tazApi");
        tazApi.openUrl = function (url) { window.location.href = url };
        tazApi.openImage = function (url) {
          tazApi.call("openImage", undefined, url)
        };
        tazApi.setBookmark = function (artName, hasBookmark, showToast) {
          tazApi.call("setBookmark", undefined, artName, hasBookmark, showToast);
        };
        tazApi.getBookmarks = function (callback) {
          tazApi.call("getBookmarks", callback);
        };
        tazApi.shareArticle = function (artName) {
          tazApi.call("shareArticle", undefined, artName);
        };
        tazApi.trackAdIfNeeded = function(adIdentifier, htmlFilename) {
          tazApi.call("trackAdIfNeeded", undefined, adIdentifier, htmlFilename);
        };
        tazApi.gotoIssue = function (issueDate) {
          tazApi.call("gotoIssue", undefined, issueDate);
        };
        tazApi.toast = function(msg, duration, callback) {
          tazApi.call("toast", callback, msg, duration);
        };
        tazApi.setDynamicStyles = function() {
          tazApi.call("setDynamicStyles", undefined);
        };
        tazApi.gotoStart = function() {
          tazApi.call("gotoStart", undefined);
        };
        tazApi.togglePlayButton = function(mediaSyncId, file) {
          tazApi.call("togglePlayButtonNative", undefined, mediaSyncId, file);
        };
        tazApi.togglePlayButtonSection = function(mediaSyncId, file) {
          tazApi.call("togglePlayButtonNative", undefined, mediaSyncId, file);
        };
        \(Defaults.multiColumnMode ? scrollToPosJsH : scrollToPosJsV)
        log2bridge(tazApi);\n
        """
  }
}
