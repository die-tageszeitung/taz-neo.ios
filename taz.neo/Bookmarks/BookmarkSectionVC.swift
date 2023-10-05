//
//  BookmarkSectionVC.swift
//  taz.neo
//
//  Created by Norbert Thies on 18.06.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/**
 * A simple subclass of SectionVC with som additional flavours for bookmark handling.
 */
open class BookmarkSectionVC: SectionVC, ContextMenuItemPrivider {
  public var menu: MenuActions? {
    return issue._contextMenu(group: 0)
  }
  
  var headerPlayButtonContextMenu: ContextMenu?
  
  private lazy var headerPlayButton: Button<ImageView> = {
    let btn = Button<ImageView>()
    btn.onTapping { [weak self] _ in
      guard let sissue = self?.delegate.issue as? BookmarkIssue else { return }
      ArticlePlayer.singleton.play(issue: sissue,
                                   startFromArticle: nil,
                                   enqueueType: .replaceCurrent)
    }
    btn.pinSize(CGSize(width: 36, height: 36))
    btn.hinset = 0.1//20%
    btn.color = Const.Colors.appIconGrey
    return btn
  }()
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    self.header.addSubview(headerPlayButton)
    pin(headerPlayButton.right, to: self.header.right, dist: -10)
    headerPlayButton.centerY()
    
    headerPlayButtonContextMenu = ContextMenu(view: headerPlayButton.buttonView)
    headerPlayButtonContextMenu?.itemPrivider = self
    
    Notification.receive(Const.NotificationNames.audioPlaybackStateChanged) { [weak self] msg in
      if let isPlaying = msg.content as? Bool {
        self?.headerPlayButton.buttonView.name
        = isPlaying
        ? "audio-active"
        : "audio"
      }}
  }
  
  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    headerPlayButton.activeColor = Const.SetColor.CTDate.color
    headerPlayButton.buttonView.name
    = ArticlePlayer.singleton.isPlaying
    ? "audio-active"
    : "audio"
  }
  
  // We don't have a toolbar
  override func setupToolbar() {}
  
  // Scroll to article position in bookmark section
  override public var article: Article? {
    didSet {
      if let art = article,
         let wv = currentWebView {
        let id = File.progname(art.html?.name ?? "")
        let js = """
        {
          let id = document.getElementById("\(id)");
          if (id) { id.scrollIntoView({block: "center"}); }
        } 
        """
        wv.jsexec(js)
      }
      (self.delegate as? BookmarkNC)?.reloadIfNeeded(article: article)
    }
  }
  
  /// Remove cache before reloading
  override open func reload() {
    URLCache.shared.removeAllCachedResponses()
    super.reload()
  }
  
}

extension BookmarkSectionVC: UsageTracker {
  public var path:[String]? { ["bookmarks", "list"]}
}
