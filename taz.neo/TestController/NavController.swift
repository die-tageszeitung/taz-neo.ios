//
//  NavController.swift
//
//  Created by Norbert Thies on 10.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

class LocalStartupView: UIView {
  var startupLogo: UIImage?
  var imageView: UIImageView?
  
  override init(frame: CGRect) {
    startupLogo = UIImage(named: "StartupLogo")
    imageView = UIImageView(image: startupLogo)
    super.init(frame: frame)
    backgroundColor = AppColors.tazRot
    if let iv = imageView {
      addSubview(iv)
      pin(iv.centerX, to: self.centerX)
      pin(iv.centerY, to: self.centerY)
    }
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
}

class NavController: UINavigationController {
  
  var startupView = LocalStartupView()
  lazy var consoleLogger = Log.Logger()
  lazy var viewLogger = Log.ViewLogger()
  lazy var fileLogger = Log.FileLogger()
  let net = NetAvailability()
  var feeder: GqlFeeder!
  var feed: Feed?
  var issue: Issue?
  lazy var dloader = Downloader(feeder: feeder)
  lazy var db = Database("ArticleDB")
  
  var sectionViews: ContentVC?
  var articleViews: ContentVC?
  var article2sections: [String:[String]] = [:]
  var sections: [String] = []
  var currentSection: String? = nil

  func setupLogging() {
    let logView = viewLogger.logView
    logView.isHidden = true
    view.addSubview(logView)
    logView.pinToView(view)
    Log.append(logger: consoleLogger, viewLogger, fileLogger)
    Log.minLogLevel = .Debug
    Log.onFatal { msg in self.log("fatal closure called, error id: \(msg.id)") }
    net.onChange { (flags) in self.log("net changed: \(flags)") }
    net.whenUp { self.log("Network up") }
    net.whenDown { self.log("Network down") }
    let nd = UIApplication.shared.delegate as! AppDelegate
    nd.onSbTap { tview in 
      if nd.wantLogging {
        if logView.isHidden {
          self.view.bringSubviewToFront(logView) 
          logView.scrollToBottom()
          logView.isHidden = false
        }
        else {
          self.view.sendSubviewToBack(logView)
          logView.isHidden = true
        }
      }
    }
    nd.permitPush { pn in
      if pn.isPermitted { self.debug("Push Permission granted") }
      else { self.debug("No push permission") }
    }
    nd.onReceivePush { (pn, payload) in
      self.debug(payload.toString())
    }
  } 
  
  func writeTazApiCss(topMargin: CGFloat, bottomMargin: CGFloat) {
    let dir = feeder.resourcesDir
    dir.create()
    let cssFile = File(dir: dir.path, fname: "tazApi.css")
    let cssContent = """
      #content {
        padding-top: \(topMargin)px;
        padding-bottom: \(bottomMargin)px;
      } 
    """
    File.open(path: cssFile.path, mode: "w") { f in f.writeline(cssContent) }
  }
  
  func setupFeeder(closure: @escaping (Result<[Issue],Error>)->()) {
    self.feeder = GqlFeeder(title: "taz", url: "https://dl.taz.de/appGraphQl") { (res) in
      guard let nfeeds = res.value() else { return }
      self.debug("Feeder \"\(self.feeder.title)\" provides \(nfeeds) feeds.")
      self.feeder.authenticate(account: "test", password: "test") { 
        [weak self] (res) in
        guard let _ = res.value() else { return }
        self?.debug(self?.feeder.toString())
        if let feeds = self?.feeder.feeds {
          self!.feed = feeds[0]
          self!.feeder.overview(feed: self!.feed!, closure: closure) 
        }
      }
    }
  }
  
  func loadIssue(closure: @escaping (Error?)->()) {
    self.dloader.downloadIssue(issue: self.issue!) { [weak self] err in
      if err != nil { self?.debug("Issue DL Errors: last = \(err!)") }
      else { self?.debug("Issue DL complete") }
      closure(err)
    }
  }
  
  func loadSection(section: Section, closure: @escaping (Error?)->()) {
    self.dloader.downloadSection(issue: self.issue!, section: section) { [weak self] err in
      if err != nil { self?.debug("Section DL Errors: last = \(err!)") }
      else { self?.debug("Section DL complete") }
      closure(err)
    }   
  }
  
  func loadArticle(article: Article, closure: @escaping (Error?)->()) {
    dloader.downloadArticle(issue: self.issue!, article: article) { [weak self] err in
      if err != nil { self?.debug("Article DL Errors: last = \(err!)") }
      else { self?.debug("Article DL complete") }
      closure(err)
    }   
  }
  
  func popArticle() {
    if self.currentSection != nil {
      self.popViewController(animated: false)
      self.currentSection = nil
      self.articleViews = nil
    }
  }
  
  func article2section(index: Int) {
    articleViews!.slider.close()
    popArticle()
    moveSection(to: index)
  }
  
  func sectionIndexFromCurrentArticle() -> Int? {
    if let aviews = self.articleViews,
      let fname = aviews.current?.url.lastPathComponent,
       let sects = article2sections[fname] {
      var next: String
      if let s = currentSection, sects.contains(s) { next = s }
      else { next = sects[0] }
      if let index = sections.firstIndex(of: next) { return index }
    }
    return nil
  }
  
  func setArticleHeader() {
    if let secidx = sectionIndexFromCurrentArticle() {
       let section = issue!.sections![secidx]
      articleViews!.header.title = section.title ?? section.name
      articleViews!.header.subTitle = nil
    }
  }
  
  func backFromArticle() {
    if let index = sectionIndexFromCurrentArticle() { article2section(index: index) }
  }
  
  func pushArticleViews(from: URL?, link: URL?) {
    debug("\(from?.lastPathComponent ?? "undefined") -> \(link?.lastPathComponent ?? "undefined")")
//    let path = feeder.issueDir(issue: issue!).path
    if currentSection == nil {
      currentSection = from?.lastPathComponent
      if articleViews == nil {
        articleViews = ContentVC(contents: issue!.allArticles, isLargeHeader: false)
        articleViews!.contentTable?.onSectionPress { [weak self] sectionIndex in
          self?.article2section(index: sectionIndex)
        }
        articleViews!.onBack { [weak self] _ in self?.backFromArticle() }
        articleViews!.contentTable?.onImagePress { [weak self] in
          self?.article2section(index: 0)
        }
        articleViews!.onDisplay { (idx) in self.setArticleHeader() }
        //articleViews?.displayFiles(path: path, files: issue!.articleHtml)
        pushViewController(articleViews!, animated: false)
      }
    }
    if let link = link { articleViews?.gotoUrl(url: link) }
  }
  
  func moveSection(to index: Int) {
    if let sections = issue?.sections {
      var next: String?
      if index >= sections.count {
        next = issue?.imprint?.html.fileName
      }
      else { next = sections[index].html.fileName }
      if let next = next { 
        let path = feeder.issueDir(issue: issue!).path
        sectionViews!.gotoUrl(path: path, file: next) 
      }
    }
  }
  
  func setSectionHeader(index: Int) {
    let sections = issue!.sections!
    var title: String
    if index >= sections.count { 
      title = issue!.imprint!.title ?? "Impressum"
    }
    else {
      let section = issue!.sections![index]
      title = section.title ?? section.name
    }
    sectionViews!.header.title = title
    sectionViews!.header.subTitle = issue!.date.gLowerDateString(tz: feeder.timeZone)
  }

  func pushSectionViews() {
    var contents: [Content] = issue!.sections!
    contents += issue!.imprint!
    sectionViews = ContentVC(contents: contents, isLargeHeader: true)
    article2sections = issue!.article2sectionHtml
    //let path = feeder.issueDir(issue: issue!).path
    sectionViews!.whenLinkPressed { [weak self] (from, link) in
      self?.pushArticleViews(from: from, link: link)
    }    
    sectionViews!.contentTable?.onSectionPress { [weak self] sectionIndex in
      self?.sectionViews!.slider.close()
      self?.moveSection(to: sectionIndex)
    }
    sectionViews!.contentTable?.onImagePress { [weak self] in
      self?.sectionViews!.slider.close()
      self?.moveSection(to: 0)
    }
    sectionViews!.onDisplay { (idx) in 
      self.setSectionHeader(index: idx)
    }
    pushViewController(sectionViews!, animated: false)
    sections = issue!.sectionHtml
    //sectionViews!.displayFiles(path: path, files: sections)
    delay(seconds: 1) {
      self.sectionViews!.slider.open() { _ in
        delay(seconds: 1) {
          self.sectionViews!.slider.close() { _ in
            self.sectionViews!.slider.blinkButton()
          }
        }
      }
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    isNavigationBarHidden = true
    self.view.addSubview(startupView)
    pin(startupView, to: self.view)
    setupLogging()
    db.open { err in 
      guard err == nil else { return }
      self.debug("DB opened: \(self.db)")
      self.setupFeeder { [weak self] res in
        guard let ovwIssues = res.value() else { self?.fatal(res.error()!); return }
        // get most recent issue
        self?.feeder.issue(feed: self!.feed!, date: ovwIssues[0].date) { [weak self] res in
          guard let issue = res.value() else { self?.fatal(res.error()!); return }
          self?.issue = issue
          self?.loadIssue { err in
            if err != nil { self?.fatal(err!) }
          }
          // load "Moment" and 1st section HTML before pushing the web view
          self?.loadSection(section: self!.issue!.sections![0]) { [weak self] err in
            if err != nil { self?.fatal(err!) }
            self?.dloader.downloadMoment(issue: self!.issue!) { [weak self] err in
              if err != nil { self?.fatal(err!) }
              self?.pushSectionViews()
              self?.startupView.isHidden = true
            }
          }
        }
      }
    }
  }
  
} // NavController
