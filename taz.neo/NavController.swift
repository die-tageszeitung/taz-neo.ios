//
//  NavController.swift
//
//  Created by Norbert Thies on 10.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit

class NavController: UINavigationController {
  
  var sectionViews: TazWebViewCollectionVC?
  var articleViews: TazWebViewCollectionVC?
  var contents = DummyContentController()
  var articles: [String] = []
  var section2articles: [String:[String]] = [:]
  var article2section: [String:String] = [:]
  var section2indices: [String:(first:Int, last:Int)] = [:]
  var sectionFiles: [String] = []
  var currentSection: String? = nil
  
  func popArticle() {
    if self.currentSection != nil {
      self.popViewController(animated: false)
      self.currentSection = nil
      self.articleViews = nil
    }
  }
  
  func pushWebViewCollection() {
    sectionViews = TazWebViewCollectionVC()
    let path = Bundle.main.resourcePath! + "/Issue.bundle/"
    let sections = ["taz eins":"seite1.html", "inland": "inland.html",
                    "wirtschaft+umwelt": "wirtschaft.umwelt.html", "ausland": "ausland.html",
                    "meinung+diskussion": "meinung.diskussion.html", "taz zwei": "taz.zwei.html",
                    "kultur": "kultur.html", "medien": "medien.html", "leibesübungen": "leibesuebungen.html",
                    "die wahrheit": "wahrheit.html", "taz berlin": "berlin.html", "taz nord": "nord.html",
                    /*"impressum": "art00045088.html"*/]
    setupArticles()
    
    NotificationCenter.default.addObserver(forName: Notification.Name("statusBarTouched"),
      object: nil, queue: nil ) { [weak self] event in
        if let this = self {
          this.debug("status bar tapped")
          this.popArticle()
        }
    }
    
    sectionViews!.whenLinkPressed { [weak self] (from, link) in
      if let this = self {
        this.debug("\(from.lastPathComponent) -> \(link.lastPathComponent)")
        if this.currentSection == nil {
          this.currentSection = from.lastPathComponent
          if this.articleViews == nil {
            this.articleViews = TazWebViewCollectionVC()
            this.articleViews?.displayFiles(path: path, files: this.articles)
            this.articleViews?.onTazButton { [weak self] in
              guard let this = self else { return }
              this.present(this.contents, animated: false, completion: nil)
            }
          }
          this.pushViewController(this.articleViews!, animated: false)
          this.articleViews?.gotoUrl(url: link)
        }
      }
    }
    
    contents.modalPresentationStyle = .overCurrentContext
    
    sectionViews!.onTazButton { [weak self] in
      guard let this = self else { return }
      this.present(this.contents, animated: false, completion: nil)
    }
    
    contents.onTazButton { [weak self] in
      guard let this = self else { return }
      this.contents.dismiss(animated: false, completion: nil)
    }
    
    contents.onBackButton { [weak self] in
      guard let this = self else { return }
      this.contents.dismiss(animated: false, completion: nil)
      this.popArticle()
    }
    
    contents.onContent { [weak self] section in
      guard let this = self else { return }
      this.contents.dismiss(animated: false, completion: nil)
      this.popArticle()
      if let next = sections[section] {
        this.sectionViews!.gotoUrl(next)
      }
    }
    
    pushViewController(sectionViews!, animated: false)
    sectionViews!.displayFiles(path: path, files: sectionFiles)
  }
  
  func pushTestController() {
    pushViewController(TestController(), animated: false)
  }
  
  func pushContentController() {
    pushViewController(DummyContentController(), animated: false)
  }
  
  override func viewDidLoad() {
    Log.minLogLevel = .Debug
    //debug("loaded")
    super.viewDidLoad()
    isNavigationBarHidden = true
    pushWebViewCollection()
    //pushTestController()
    //pushContentController()
  }
  
}
