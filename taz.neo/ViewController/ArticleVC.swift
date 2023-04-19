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
  
  @Default("smartBackFromArticle")
  var smartBackFromArticle: Bool
    
  var hasValidAbo: Bool {feederContext.isAuthenticated && !Defaults.expiredAccount}
  var needValidAboToShareText: String {
    if feederContext.isAuthenticated == false {
      return "Sie müssen angemeldet sein, um Texte zu teilen!"
    }
    //otherwise: Defaults.expiredAccount
    return "Sie benötigen ein gültiges Abonnement, um Texte zu teilen!"
  }
  
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
    //not delete articles without filename
    guard let name = article.html?.name, name.length > 0 else { return }
    if let idx = articles.firstIndex(where: { $0.html?.name == name }) {
      articles.remove(at: idx)
      deleteContent(at: idx)
    }
  }
  
  /// Insert Article into page collection
  func insert(article: Article) {
    //not insert articles without filename
    guard let name = article.html?.name, name.length > 0 else { return }
    // only insert new Article
    guard articles.firstIndex(where: { $0.html?.name == name }) == nil
    else { return }
    let all = delegate.issue.allArticles
    if let idx = all.firstIndex(where: { $0.html?.name == name }) {
      articles.insert(article, at: idx)
      insertContent(content: article, at: idx)
    }
  }
  
  func displayBookmark(art: Article) {
    bookmarkButton.isHidden = art.html?.isEqualTo(delegate.issue.imprint?.html) ?? false
    
    if art.hasBookmark { self.bookmarkButton.buttonView.name = "star-fill" }
    else { self.bookmarkButton.buttonView.name = "star" }
  }
  
  func toggleBookmark(art: StoredArticle?) {
    guard let art = art else { return }
    var msg: String
    if art.hasBookmark { msg = "Der Artikel wurde aus ihrer Leseliste entfernt." }
    else { msg = "Der Artikel wurde in ihrer Leseliste gespeichert." }
    Toast.show("<h3>\(art.title ?? "")</h3>\(msg)", minDuration: 0)
    art.hasBookmark.toggle()
  }
  
  func setup() {
    if let arts = self.adelegate?.issue.allArticles {
      self.articles = arts
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
         let art = self.article,
         cart.html?.name == art.html?.name {
         self.displayBookmark(art: art)
      }
    }
    onDisplay { [weak self] (idx, oview) in
      guard let self = self else { return }
      guard let art = self.articles.valueAt(idx) else {
        ///prevent crash on search result login on 2nd or later load more results
        log("fail to access artikel at index: \(idx)  when only \(self.articles.count) exist")
        return
      }
      if self.smartBackFromArticle {
        self.adelegate?.article = art
      }
      self.shareButton.isHidden = self.hasValidAbo && art.onlineLink?.isEmpty != false
      self.setHeader(artIndex: idx)
      self.issue.lastArticle = idx
      let player = ArticlePlayer.singleton
      if player.isPlaying() { async { player.stop() } }
      if art.canPlayAudio {
        self.playButton.buttonView.name = "audio"
        self.onPlay { [weak self] _ in
          guard let self = self else { return }
          if let title = self.header.title ?? art.title {
            art.toggleAudio(issue: self.issue, sectionName: title )
          }
          if player.isPlaying() { self.playButton.buttonView.name = "audio-active" }
          else { self.playButton.buttonView.name = "audio" }
        }
      }
      else { self.onPlay(closure: nil) }
      player.onEnd { [weak self] err in
        self?.playButton.buttonView.name = "audio"
        guard let err = err else { return }
        //Offline Error: err._userInfo?.value(forKey: "NSUnderlyingError") as? NSError)?.code == -1020
        self?.debug("Failed to play with error: \(err)")
        Toast.show("Die Vorlesefunktion konnte nicht gestartet werden.\nBitte überprüfen Sie Ihre Internetverbindung und versuchen Sie es erneut.")
      }
      self.onBookmark { [weak self] _ in
        guard let self = self else { return }
        self.toggleBookmark(art: art as? StoredArticle)
      }
      if art.primaryIssue?.isReduced ?? false {
        self.atEndOfContent() { [weak self] isAtEnd in
          if isAtEnd { self?.feederContext.authenticate() }
        }
      }
      self.displayBookmark(art: art)///hide bookmarkbutton for imprint!
      self.debug("on display: \(idx), article \(art.html?.name ?? "-"):\n\(art.title ?? "Unknown Title")")
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
    if let art = article, let name = art.html?.name {
      if let sections = adelegate?.article2section[name],
         sections.count > 0 {
        let section = sections[0]
        if let title = section.title, let articles = section.articles {
          var i = 0
          for a in articles {
            if a.html?.name == article?.html?.name { break }
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
      else if art.title != nil,
              art.html?.isEqualTo(adelegate?.issue.imprint?.html) ?? false,
              art.sectionTitle == nil {
        header.title = art.title
        header.pageNumber = nil
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
        dialogue.present(item: data, altText: altText, onlineLink: art.onlineLink, view: button,
                         subject: art.title)
      }
    }
  }

  // Export/Share article
  public static func exportArticle(article: Article?, artvc: ArticleVC? = nil, 
                                   from button: UIView? = nil) {
    
    let img = article?.images?.first?.image(dir: artvc?.delegate.issue.dir)
    
    if let art = article,
       let link = art.onlineLink,
       !link.isEmpty{
          let dialogue = ExportDialogue<Any>()
        dialogue.present(item: link,
                       altText: nil,
                       onlineLink: link,
                       view: button,
                       subject: art.title,
                       image: img)
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
      if (self.article?.onlineLink ?? "").isEmpty {
        Alert.actionSheet(message: self.needValidAboToShareText,
                          actions: UIAlertAction.init( title: self.feederContext.isAuthenticated ? "Weitere Informationen" : "Anmelden",
                                                       style: .default ){ [weak self] _ in
          self?.feederContext.authenticate()
        })
      } else {
        ArticleVC.exportArticle(article: self.article, artvc: self, from: self.shareButton)
      }
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
