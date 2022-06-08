//
//  ArticleVC.swift
//
//  Created by Norbert Thies on 14.01.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib
import WebKit

/// The protocol used to communicate with calling VCs
public protocol ArticleVCdelegate: IssueInfo {
  var section: Section? { get }
  var sections: [Section] { get }
  var article: Article? { get set }
  var article2section: [String:[Section]] { get }
  func displaySection(index: Int)
  func linkPressed(from: URL?, to: URL?)
  func closeIssue()
}

/// The Article view controller managing a collection of Article pages
open class ArticleVC: ContentVC {
    
  public var articles: [Article] = []
  public var article: Article? { 
    if let i = index { return articles[i] }
    return nil
  }
  
  public override var delegate: IssueInfo! {
    didSet {
      if delegate == nil { return }
      guard let _ = delegate as? ArticleVCdelegate else {
        fatal("ArticleVC.delegate must be of type ArticleVCdelegate")
        return
      }
      if oldValue == nil { self.setup() } 
    }
  }
  
  public weak var adelegate: ArticleVCdelegate? {
    get { delegate as? ArticleVCdelegate }
    set { delegate = newValue }
  }
  
  /// Remove Article from page collection
  func delete(article: Article) {
    if let idx = articles.firstIndex(where: { $0.html.name == article.html.name }) {
      articles.remove(at: idx)
      deleteContent(at: idx)
    }
  }
  
  /// Insert Article into page collection
  func insert(article: Article) {
    // only insert new Article
    guard articles.firstIndex(where: { $0.html.name == article.html.name }) == nil
    else { return }
    let all = delegate.issue.allArticles
    if let idx = all.firstIndex(where: { $0.html.name == article.html.name }) {
      articles.insert(article, at: idx)
      insertContent(content: article, at: idx)
    }
  }
  
  func displayBookmark(art: Article) {
    if art.hasBookmark { self.bookmarkButton.buttonView.name = "star-fill" }
    else { self.bookmarkButton.buttonView.name = "star" }
  }
  
  func setup() {
    if let arts = self.adelegate?.issue.allArticles {
      self.articles = arts
    }
    
    if issue.isReduced { 
      atEndOfContent() { [weak self] isAtEnd in
        if isAtEnd { self?.feederContext.authenticate() }
      } 
    }
    super.setup(contents: articles, isLargeHeader: false)
    contentTable?.onSectionPress { [weak self] sectionIndex in
      guard let self = self, let adelegate = self.adelegate else { return }
      if sectionIndex >= adelegate.sections.count {
        self.debug("*** Action: Impressum pressed")
      }
      else {
        self.debug("*** Action: Section \(sectionIndex) " +
          "(delegate.sections[sectionIndex])) in Slider pressed")
      }
      self.adelegate?.displaySection(index: sectionIndex)
      self.slider?.close()
      self.navigationController?.popViewController(animated: false)
    }
    contentTable?.onImagePress { [weak self] in
      self?.debug("*** Action: Moment in Slider pressed")
      self?.slider?.close()
      self?.navigationController?.popViewController(animated: false)
      self?.adelegate?.closeIssue()
    }
    Notification.receive("BookmarkChanged") { [weak self] msg in
      guard let self = self else {return}
      if let cart = msg.sender as? StoredArticle,
         self.isVisible,
         let art = self.article,
         cart.html.name == art.html.name {
         self.displayBookmark(art: art)
      }
    }
    onDisplay { [weak self] (idx, oview) in
      if let self = self {
        var art = self.articles[idx]
        self.adelegate?.article = art
        self.setHeader(artIndex: idx)
        self.issue.lastArticle = idx
        let player = ArticlePlayer.singleton
        if player.isPlaying() { async { player.stop() } }
        if art.canPlayAudio {
          self.playButton.buttonView.name = "audio"
          self.onPlay { [weak self] _ in
            guard let self = self else {return}
            if let title = self.header.title ?? art.title {
              art.toggleAudio(issue: self.issue, sectionName: title )
            }
            if player.isPlaying() { self.playButton.buttonView.name = "audio-active" }
            else { self.playButton.buttonView.name = "audio" }
          }
        }
        else { self.onPlay(closure: nil) }
        self.onBookmark { _ in
          art.hasBookmark.toggle()
          ArticleDB.save()
        }
        self.displayBookmark(art: art)
        self.debug("on display: \(idx), article \(art.html.name)")
      }
    }
    whenLinkPressed { [weak self] (from, to) in
      /** FIX wrong Article shown (most errors on iPad, some also on Phone)
          after re-enter app due wired Scroll Pos change
          @see:  https://developer.apple.com/forums/thread/47100
          unfortunately is our behaviour quite complex, a simple return in viewWillTransition...
          destroys the layout or raise other errors
          so this is currently the most effective solution
       **/
      if UIApplication.shared.applicationState != .active { return }
      self?.adelegate?.linkPressed(from: from, to: to)
    }
    whenLoaded {
      Notification.send(Const.NotificationNames.articleLoaded)
    }
    header.onTitle { [weak self] _ in
      self?.debug("*** Action: ToSection pressed")
      self?.navigationController?.popViewController(animated: true)
    }
    header.titletype = .article
  }
    
  // Define Header elements
  #warning("ToDo: Refactor get HeaderField with Protocol! (ArticleVC, SectionVC...)")
  func setHeader(artIndex: Int) {
    if let art = article {
      if let sections = adelegate?.article2section[art.html.name],
         sections.count > 0 {
        let section = sections[0]
        if let title = section.title, let articles = section.articles {
          var i = 0
          for a in articles {
            if a.html.name == article?.html.name { break }
            i += 1
          }
          if let st = art.sectionTitle { header.title = st }
          else { header.title = "\(title)" }
       
          
          if section is BookmarkSection {
            header.titletype = .search
            header.subTitle = "Ausgabe \(art.issueDate.short)"
            header.pageNumber = "\(i+1) von \(articles.count)"
          }
          else {
            header.pageNumber = "\(i+1)/\(articles.count)"
          }
        }        
      }
    }
  }
  
  @available(iOS 14.0, *)
  private func exportPdf(article art: Article, from button: UIView? = nil) {
    if let webView = currentWebView {
      webView.pdf { data in
        guard let data = data else { return }
        let dialogue = ExportDialogue<Data>()
        let altText = "\(art.teaser ?? "")\n\(art.onlineLink!)"
        dialogue.present(item: data, altText: altText, view: button,
                         subject: art.title)
      }
    }
  }

  // Export/Share article
  public static func exportArticle(article: Article?, artvc: ArticleVC? = nil, 
                                   from button: UIView? = nil) {
    if let art = article {
      if let link = art.onlineLink, !link.isEmpty {
        if let url = URL(string: link) {
          let actions = UIAlertController.init( title: nil, message: nil,
            preferredStyle:  .actionSheet )
          actions.addAction( UIAlertAction.init( title: "Teilen", style: .default,
            handler: { handler in
              //previously used PDFEXPORT Compiler Flags
              if App.isAvailable(.PDFEXPORT), #available(iOS 14, *) {
                artvc?.exportPdf(article: art, from: button)
              } else {
                let dialogue = ExportDialogue<Any>()
                dialogue.present(item: "\(art.teaser ?? "")\n\(art.onlineLink!)",
                                 view: button, subject: art.title)
              }
          } ) )
          actions.addAction( UIAlertAction.init( title: "Online-Version", style: .default,
          handler: {
            (handler: UIAlertAction) in
            Log.debug("Going to online version: \(link)")
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
          } ) )
          actions.addAction( UIAlertAction.init( title: "Abbrechen", style: .default,
          handler: {
            (handler: UIAlertAction) in
          } ) )
          actions.presentAt(button)
        } 
      }
    } 
  }
  
  public override func viewWillAppear(_ animated: Bool) {
    if self.invalidateLayoutNeededOnViewWillAppear {
      self.collectionView?.isHidden = true
    }
    super.viewWillAppear(animated)
  }
  
  public override func viewDidAppear(_ animated: Bool) {
    if self.invalidateLayoutNeededOnViewWillAppear {
      self.invalidateLayoutNeededOnViewWillAppear = false
      self.collectionView?.collectionViewLayout.invalidateLayout()
      self.collectionView?.fixScrollPosition()
      self.collectionView?.showAnimated()
    }
    super.viewDidAppear(animated)
    onShare { [weak self] _ in
      guard let self = self else { return }
      self.debug("*** Action: Share Article")
      ArticleVC.exportArticle(article: self.article, artvc: self, from: self.shareButton)
    }
    
    if App.isAvailable(.SEARCH_CONTEXTMENU) {
      let suche = UIMenuItem(title: "Suche", action: #selector(search))
      UIMenuController.shared.menuItems = [suche]
    }
  }
  
  public override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)  
    let player = ArticlePlayer.singleton
    if player.isPlaying() { async { player.stop() } }
  }
  
  public override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    if App.isAvailable(.SEARCH_CONTEXTMENU) {
      UIMenuController.shared.menuItems = nil
    }
  }
} // ArticleVC

//MARK: - Context Menu Actions
extension ArticleVC {
  @objc func search() {
    self.currentWebView?.evaluateJavaScript("window.getSelection().toString()", completionHandler: {[weak self] selectedText, err in
      guard let self = self else {return}
      if let e = err { self.log(e.description)}
      //#warning("ToDo: 0.9.4+ Implement Search")
      if let txt = selectedText { print("You selected: \(txt)")}
      else { print("no text selection detected")}
    })
  }
}
