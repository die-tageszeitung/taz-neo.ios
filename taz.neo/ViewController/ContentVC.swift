//
//  ContentVC.swift
//
//  Created by Norbert Thies on 25.09.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib


var TopMargin = 65
var BottomMargin = 34

// A ContentUrl provides a WebView URL for Articles and Sections
public class ContentUrl: WebViewUrl, DoesLog {
  
  public var content: Content
  public var path: String
  public lazy var url: URL = URL(fileURLWithPath: path + "/" + content.html.fileName)

  private var availableClosure: (()->())?
  private var loadClosure: (ContentUrl)->()
  private var _isAvailable = false
  public var isAvailable: Bool {
    get {
      guard !_isAvailable else { return true }
      for f in content.files {
        debug("fileNameExists(\(f.fileName)): \(f.fileNameExists(inDir: path))")
        if !f.fileNameExists(inDir: path) { self.loadClosure(self); return false }
      }
      _isAvailable = true
      return true
    }
    set {
      _isAvailable = true
      if let closure = availableClosure { closure() }
    }
  }
  public func whenAvailable(closure: @escaping ()->()) { availableClosure = closure }

  public func waitingView() -> UIView? {
    let view = LoadingView()
    view.topText = content.title ?? ""
    view.bottomText = "wird geladen..."
    return view
  }
  
  public init(path: String, issue: Issue, content: Content, load: @escaping (ContentUrl)->()) {
    self.content = content
    self.path = path
    self.loadClosure = load
  }
  
} // ContentUrl

/**
 A ContentVC is a view controller that displays an array of Articles or Sections 
 in a collection of WebViews
 */
open class ContentVC: WebViewCollectionVC {

  public var contentTable: ContentTableVC?
  public var contents: [Content] = []
  public var feeder: Feeder { return contentTable!.feeder! }
  public var issue: Issue { return contentTable!.issue! }
  public var feed: Feed { return issue.feed }
  public var dloader: Downloader!
  lazy var slider = ButtonSlider(slider: contentTable!, into: self)

  public var toolBar = Toolbar()
  private var toolBarConstraint: NSLayoutConstraint?
  public var backButton = Button<LeftArrowView>()
  private var backClosure: ((ContentVC)->())?
  
  public var header = HeaderView()
  public var isLargeHeader = false
  
  /// Define the closure to call when the back button is tapped
  public func onBack(closure: @escaping (ContentVC)->()) 
    { backClosure = closure }
  
  func setupToolbar() {
    backButton.onPress { [weak self] _ in 
      if let closure = self?.backClosure { closure(self!) } 
    }
    backButton.pinWidth(30)
    backButton.pinHeight(30)
    backButton.isBistable = false
    backButton.lineWidth = 0.06
    toolBar.backgroundColor = UIColor.rgb(0x101010)
    toolBar.addButton(backButton, direction: .left)
    toolBar.setButtonColor(UIColor.rgb(0xeeeeee))
    self.view.addSubview(toolBar)
    pin(toolBar.left, to: self.view.left)
    pin(toolBar.right, to: self.view.right)
    toolBar.pinHeight(44)
    toolBarConstraint = pin(toolBar.bottom, to: self.view.bottom)
  }
  
  func hideToolBar(hide: Bool = true) {
    if hide {
      UIView.animate(withDuration: 0.5) {
        self.toolBarConstraint?.isActive = false
        self.toolBarConstraint = pin(self.toolBar.bottom, to: self.view.bottom, dist: 44)
        self.view.layoutIfNeeded()
      }
    }
    else {
      UIView.animate(withDuration: 0.5) {
        self.toolBarConstraint?.isActive = false
        self.toolBarConstraint = pin(self.toolBar.bottom, to: self.view.bottom)
        self.view.layoutIfNeeded()
      }   
    }
  }
  
  override public func viewDidLoad() {
    super.viewDidLoad()
    setupToolbar()
    header.installIn(view: self.view, isLarge: isLargeHeader, isMini: true)
    whenScrolled { [weak self] ratio in
      if (ratio < 0) { self?.hideToolBar(); self?.header.hide(true) }
      else { self?.hideToolBar(hide: false); self?.header.hide(false) }
    }
    let img = UIImage.init(named: "logo")
    slider.image = img
    slider.buttonAlpha = 0.9
    let path = feeder.issueDir(issue: issue).path
    let curls: [ContentUrl] = contents.map { cnt in
      ContentUrl(path: path, issue: issue, content: cnt) { [weak self] curl in
        guard let this = self else { return }
        this.dloader.downloadIssueData(issue: this.issue, files: curl.content.files) { err in
          if err == nil { curl.isAvailable = true }
        }
      }
    }
    displayUrls(urls: curls)
  }

  override public func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
  }
  
  override public func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    slider.close()
  }

  public override init() {
    self.contentTable = ContentTableVC.loadFromNib()
    super.init()
  }
  
  public func setup(feeder: Feeder, issue: Issue, contents: [Content],
                    dloader: Downloader, isLargeHeader: Bool) {
    self.contents = contents
    self.dloader = dloader
    self.isLargeHeader = isLargeHeader
    self.contentTable!.feeder = feeder
    self.contentTable!.issue = issue
    self.contentTable!.image = feeder.momentImage(issue: issue, resolution: .normal)
    self.baseDir = feeder.baseDir.path
    onBack { [weak self] _ in
      self?.navigationController?.popViewController(animated: false)
    }
  }
  
  public convenience init(feeder: Feeder, issue: Issue, contents: [Content],
                          dloader: Downloader, isLargeHeader: Bool) {
    self.init()
    setup(feeder: feeder, issue: issue, contents: contents, dloader: dloader,
          isLargeHeader: isLargeHeader)
  }
  
  required public init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
}
