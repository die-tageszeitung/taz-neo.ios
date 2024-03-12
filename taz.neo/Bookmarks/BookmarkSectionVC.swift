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
  
  override public var sectionPath:[String]? { return ["bookmarks", "list"]}
  
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
    leftTapBottomMargin = false
    super.viewDidLoad()
    self.header.addSubview(headerPlayButton)
    pin(headerPlayButton.right, to: self.header.right, dist: -10)
    headerPlayButton.centerY()
    headerPlayButton.activeColor = Const.SetColor.CTDate.color
    headerPlayButtonContextMenu = ContextMenu(view: headerPlayButton.buttonView)
    headerPlayButtonContextMenu?.itemPrivider = self
  }
  
  ///Prevent release and destroy webview functionality e.g.
  ///remove last bookmark, restore it destroyed Bookmark List
  open override func releaseOnDisappear() {}//Overwrite and do nothing here!
  
  override func updateAudioButton(){
    self.headerPlayButton.buttonView.name
    = ArticlePlayer.singleton.isPlaying
    && (ArticlePlayer.singleton.currentContent as? Article)?.hasBookmark == true
    ? "audio-active"
    : "audio"
  }
  
  func updateTapOnEdge(show: Bool? = nil){
    let ctH = self.currentWebView?.scrollView.contentSize.height
    if show == nil && (ctH ?? 0.0) == 0.0 { return }
    let show = show ?? ((ctH ?? 0.0) * 0.8  > UIWindow.size.height)
    ///topInset looks strange, something is wrong but the result/placement is over multiple devices the best currently
    ///maybe re-think sectionVC with Tabbar insets and pin
    tapButtonsBottomDist = (show ?  88 - UIWindow.topInset : 220)
  }
  
  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    headerPlayButton.buttonView.name
    = ArticlePlayer.singleton.isPlaying
    ? "audio-active"
    : "audio"
  }
  
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    updateTapOnEdge()
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
