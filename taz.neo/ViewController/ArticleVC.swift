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
  public var adelegate: ArticleVCdelegate? {
    get { delegate as? ArticleVCdelegate }
    set { delegate = newValue }
  }
  
  func setup() {
    guard let delegate = self.adelegate else { return }
    self.articles = delegate.issue.allArticles
    if issue.isReduced { 
      atEndOfContent() { [weak self] isAtEnd in
        if isAtEnd { self?.feederContext.authenticate() }
      } 
    }
    super.setup(contents: articles, isLargeHeader: false)
    contentTable?.onSectionPress { [weak self] sectionIndex in
      guard let self = self else { return }
      if sectionIndex >= delegate.sections.count {
        self.debug("*** Action: Impressum pressed")
      }
      else {
        self.debug("*** Action: Section \(sectionIndex) " +
          "(delegate.sections[sectionIndex])) in Slider pressed")
      }
      delegate.displaySection(index: sectionIndex)
      self.slider?.close()
      self.navigationController?.popViewController(animated: false)
    }
    contentTable?.onImagePress { [weak self] in
      self?.debug("*** Action: Moment in Slider pressed")
      self?.slider?.close()
      self?.navigationController?.popViewController(animated: false)
      self?.adelegate?.closeIssue()
    }
    onDisplay { [weak self] (idx, oview) in
      if let this = self {
        let art = this.articles[idx]
        this.adelegate?.article = art
        this.setHeader(artIndex: idx)
        this.issue.lastArticle = idx
        self?.debug("on display: \(idx), article \(art.html.name)")
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
    if App.isRelease == false {
      header.onTaps(nTaps: 2) { [weak self] _ in
        guard let self = self, let art = self.article else { return }
        art.toggleAudio(sectionName: self.header.title)
      }
    }
  }
    
  // Define Header elements
  func setHeader(artIndex: Int) {
    if let art = article, 
      let sections = adelegate?.article2section[art.html.name],
      sections.count > 0 {
      let section = sections[0]
      if let title = section.title, let articles = section.articles {
        var i = 0
        for a in articles {
          if a.html.name == article?.html.name { break }
          i += 1
        }
        header.title = "\(title)"
        header.pageNumber = "\(i+1)/\(articles.count)"
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

//  public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
//    super.viewWillTransition(to: size, with: coordinator)
//    print("ARTICLE VC viewWillTransition for idx: \(index) cv:\(currentView)")
//  }
//  
  // Export/Share article
  func exportArticle(article: Article?, from button: UIView? = nil) {
    if let art = article {
      if let link = art.onlineLink, !link.isEmpty {
        if let url = URL(string: link) {
          let actions = UIAlertController.init( title: nil, message: nil,
            preferredStyle:  .actionSheet )
          //    actions.defaultStyle()//currently using default, no need to set
          actions.addAction( UIAlertAction.init( title: "Teilen", style: .default,
            handler: { [weak self] handler in
              //previously used PDFEXPORT Compiler Flags
              if App.isAvailable(.PDFEXPORT), #available(iOS 14, *) {
                self?.exportPdf(article: art, from: button)
              } else {
                let dialogue = ExportDialogue<Any>()
                dialogue.present(item: "\(art.teaser ?? "")\n\(art.onlineLink!)",
                                 view: button, subject: art.title)
              }
          } ) )
          actions.addAction( UIAlertAction.init( title: "Online-Version", style: .default,
          handler: {
            (handler: UIAlertAction) in
            self.debug("Going to online version: \(link)")
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
      self.exportArticle(article: self.article, from: self.shareButton)
    }
  }

} // ArticleVC


