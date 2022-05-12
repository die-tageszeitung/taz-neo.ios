//
//  BookmarksNC.swift
//  taz.neo
//
//  Created by Ringo Müller on 12.05.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

class BookmarksSection: SectionVC{
  override func setupToolbar() {}
}

fileprivate class PlaceholderVC: UIViewController{
  override func viewDidLoad() {
    super.viewDidLoad()
    self.view
    = PlaceholderView("Die Leseliste ist leer!",
                      image: UIImage(named: "star"))
    self.view.backgroundColor = Const.SetColor.CTBackground.color
  }
}

class BookmarksNC: UINavigationController {
  
  private var placeholderVC = PlaceholderVC()
  
  public var feederContext: FeederContext
  public lazy var bookmarkFeed = BookmarkFeed.allBookmarks(feeder: feeder)
  public var issue: Issue { bookmarkFeed.issues![0] }
  var isShowingAlert = false
  
  public lazy var sectionVC: BookmarksSection = {
    let svc = BookmarksSection(feederContext: feederContext)
    svc.delegate = self
    svc.toolBar.hide()
    svc.isStaticHeader = true
    svc.header.isLargeTitleFont = false
    svc.header.subTitle = nil
    svc.hidesBottomBarWhenPushed = false
    return svc
  }()
  
  func setup() {
    Notification.receive("BookmarkChanged") { [weak self] msg in
      // regenerate all bookmark sections
      guard let emptyRoot = self?.placeholderVC,
            let self = self else { return }
      if let art = msg.sender as? StoredArticle {
        self.bookmarkFeed.loadAllBookmmarks()
        self.bookmarkFeed.genAllHtml()
        if art.hasBookmark {
          self.sectionVC.insertArticle(art)
        }
        if self.bookmarkFeed.count <= 0 {
          self.viewControllers[0] = emptyRoot
          self.popToRootViewController(animated: true)
        }
        self.updateTabbarImage()
      }
    }
  }
  
  func updateTabbarImage(){
    tabBarItem.image
    = bookmarkFeed.count == 0
    ? UIImage(named: "star")
    : UIImage(named: "star-fill")
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if bookmarkFeed.count > 0 && self.viewControllers.first != sectionVC  {
      setViewControllers([sectionVC], animated: true)
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
  
  init(feederContext: FeederContext) {
    self.feederContext = feederContext
    super.init(rootViewController: placeholderVC)
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

extension BookmarksNC: IssueInfo {
  public func resetIssueList() {}
}
