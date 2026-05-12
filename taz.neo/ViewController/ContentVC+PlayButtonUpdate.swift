//
//  ContentVC+PlayButtonUpdate.swift
//  taz.neo
//
//  Created by Ringo Müller on 11.05.26.
//  Copyright © 2026 taz. All rights reserved.
//
import NorthLib

///  Synchronizes the audio play buttons within the WKWebView.
///  Background:
///  - `ArticleVC` has exactly one audio button and can be updated directly via DOM ID.
///  - `SectionVC`, on the other hand, contains multiple article/podcast teasers.
///    The same DOM IDs (`podcastPlayButtonSection`) appear multiple times there,
///    which is why a global `getElementById` cannot be used.
///  Solution:
///  - All `.SectionArticle` elements are iterated through.
///  - The associated article is identified via the embedded `<a href="...">`.
///  - Only the currently playing article receives the pause icon.
///  - All other podcast teasers are reset to play.
///  This ensures consistency, even when multiple podcast teasers
///  are rendered within the same section.
extension ContentVC {
  
  func updateAudioInWebview(_ webView: WebView? = nil) {
    let wv = webView ?? currentWebView
    let pc = ArticlePlayer.singleton.isPlaying ? ArticlePlayer.singleton.currentContent : nil
    let currentWebContent = contents.valueAt(index)
    let active
    = currentWebContent?.audioItem?.file?.sha256
    == ArticlePlayer.singleton.currentPlayingContent?.audioItem?.file?.sha256
    && currentWebContent?.audioItem?.file?.sha256 != nil
    (self as? ArticleVC)?.updateArticleAudioInWebview(wv, active: active)
    (self as? SectionVC)?.updateSectionAudioInWebview(wv, playingContent: pc)
  }
}

// MARK: - Section Audio Update
extension SectionVC {
  func updateSectionAudioInWebview(_ webView: WebView?, playingContent: Content?) {
    guard let webView = webView else { return }
    let audioFile = playingContent?.audioItem?.file?.fileName ?? ""
    Task {
      let js = """
          (function() {
              var activeAudioFile = "\(audioFile)";
              var sectionArticles = document.querySelectorAll('.SectionArticle');
              sectionArticles.forEach(function(sectionArticle) {
                  var playButton = sectionArticle.querySelector('#podcastPlayButtonSection');
                  if (!playButton) return;
                  var onclickAttr = playButton.getAttribute('onclick');
                  if (!onclickAttr) return;
                  // extract audiofilename from
                  // EPUBTAZ.togglePlayButtonSection('6177015', 'global/xyz.mp3')
                  var match = onclickAttr.match(/'([^']+\\.mp3)'/);
                  if (!match || !match[1]) return;
                  var buttonAudioFile = match[1];
                  var isActive = buttonAudioFile === activeAudioFile;
                  playButton.src = isActive
                      ? 'resources/ic_pause_button_teaser.svg'
                      : 'resources/ic_play_button_teaser.svg';
              });
          })();
          """
      _ = try? await webView.jsexec(js)
    }
  }
}

// MARK: - Article Audio Update

extension ArticleVC {
  
  func updateArticleAudioInWebview(_ webView: WebView?, active: Bool) {
    guard let webView = webView else { return }
    Task {
      let playIconArtSrc = active ? "resources/ic_pause_button.svg" : "resources/ic_play_button.svg"
      
      let js = """
      (function() {
          var playIcon = document.getElementById("podcastPlayButton");
          if (playIcon) { playIcon.src = "\(playIconArtSrc)";}
      })();
      """
      _ = try? await webView.jsexec(js)
    }
  }
}
