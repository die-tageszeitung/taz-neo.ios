//
//  ArticleVC.swift
//
//  Created by Norbert Thies on 14.01.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

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
      guard let this = self else { return }
      if sectionIndex >= delegate.sections.count {
        this.debug("*** Action: Impressum pressed")
      }
      else {
        this.debug("*** Action: Section \(sectionIndex) " +
          "(delegate.sections[sectionIndex])) in Slider pressed")
      }
      delegate.displaySection(index: sectionIndex)
      this.navigationController?.popViewController(animated: false)
    }
    contentTable?.onImagePress { [weak self] in
      self?.debug("*** Action: Moment in Slider pressed")
      self?.slider.close()
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
      self?.adelegate?.linkPressed(from: from, to: to)
    }
    header.onTitle { [weak self] _ in
      self?.debug("*** Action: ToSection pressed")
      self?.navigationController?.popViewController(animated: true)
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
  
  // Export/Share article
  func exportArticle(article: Article?, from button: UIView? = nil) {
    if let art = article {
      if let link = art.onlineLink, !link.isEmpty {
        if let url = URL(string: link) {
          let actions = UIAlertController.init( title: nil, message: nil,
            preferredStyle:  .actionSheet )
          actions.addAction( UIAlertAction.init( title: "Teilen", style: .default,
            handler: { handler in
            let dialogue = ExportDialogue<Any>()
            dialogue.present(item: "\(art.teaser ?? "")\n\(art.onlineLink!)", 
              view: button, subject: art.title)
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
  
  public override func viewDidAppear(_ animated: Bool) {
    onShare { [weak self] _ in
      guard let self = self else { return }
      self.debug("*** Action: Share Article")
      self.exportArticle(article: self.article, from: self.shareButton)
    }
  }

} // ArticleVC


