//
//  ArticleVC.swift
//
//  Created by Norbert Thies on 14.01.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// The protocol used to communicate with calling VCs
public protocol ArticleVCdelegate {
  var feeder: Feeder { get }
  var issue: Issue { get }
  var dloader: Downloader! { get }
  var section: Section? { get }
  var sections: [Section] { get }
  var article: Article? { get set }
  func displaySection(index: Int)
}

/// The Article view controller managing a collection of Article pages
open class ArticleVC: ContentVC {
    
  public var articles: [Article] = []
  public var article: Article? { 
    if let i = index { return articles[i] }
    return nil
  }
  public var delegate: ArticleVCdelegate? {
    didSet { if oldValue == nil { self.setup() } }
  }
  
  func setup() {
    guard let delegate = self.delegate else { return }
    self.articles = delegate.issue.allArticles
    super.setup(feeder: delegate.feeder, issue: delegate.issue, contents: articles, 
                dloader: delegate.dloader, isLargeHeader: false)
    contentTable?.onSectionPress { [weak self] sectionIndex in
      guard let this = self else { return }
      if sectionIndex >= delegate.sections.count {
        this.debug("*** Action: Impressum pressed")
      }
      else {
        this.debug("*** Action: Section \(sectionIndex) " +
          "(delegate.sections[sectionIndex])) in Slider pressed")
      }
      this.delegate?.displaySection(index: sectionIndex)
      this.navigationController?.popViewController(animated: false)
    }
    contentTable?.onImagePress { [weak self] in
      self?.debug("*** Action: Moment in Slider pressed")
      self?.delegate?.displaySection(index: 0)
      self?.navigationController?.popViewController(animated: false)
    }
    onDisplay { [weak self] (idx) in
      self?.debug("on display: \(idx)")
      if let this = self {
        this.delegate?.article = this.articles[idx]
        this.setHeader(artIndex: idx)
      }
    }
  }
    
  // Define Header elements
  func setHeader(artIndex: Int) {
    if let section = delegate?.section {
      header.title = section.title ?? ""
    }
  }
  
  // Export/Share article
  func exportArticle(article: Article?, from button: UIView? = nil) {
    if let art = article {
      if let link = art.onlineLink, !link.isEmpty {
        if let url = URL(string: art.onlineLink!) {
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
  
  public override func viewDidLoad() {
    super.viewDidLoad()
  }
  
  public override func viewDidAppear(_ animated: Bool) {
    onShare { [weak self] _ in
      guard let self = self else { return }
      self.debug("*** Action: Share Article")
      self.exportArticle(article: self.article, from: self.shareButton)
    }
  }
    
} // ArticleVC


