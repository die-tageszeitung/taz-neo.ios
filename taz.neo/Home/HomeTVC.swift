//
//  HomeTVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 01.02.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// Protocol to handle Open and Display an Issue
protocol OpenIssueDelegate {
  /// open a Issue
  func openIssue(_ issue:StoredIssue)
}

/// Protocol to handle Open and Display an Issue
protocol PushIssueDelegate {
  /// delagate back the push of a child VC to prevent multiple pushes
  func push(_ viewController:UIViewController, issueInfo: IssueDisplayService)
}

class HomeTVC: UITableViewController {
  
  /// Are we in facsimile mode
  @Default("isFacsimile")
  public var isFacsimile: Bool
  
  #warning("Refactor ContentVC should hold it's IssueInfo Reference")
  ///Needed because ContentVC did not has a strong reference to its IssueInfo Object
  ///if not using this both vars
  ///Array: Push after Download not work
  ///Var: IssueInfo no content to display
  var loadingIssueInfos:[IssueDisplayService] = []
  var issueInfo:IssueDisplayService?
  var feederContext:FeederContext
  
  override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
  //  var service: DataService
  
  /**
   Selection unten => Top Ausgabe ist selectiert
   
   Memory
   old IssueVC
    Started as App91MB scroll -36d 179MBscroll -90d 333mb
   new
   Started as App21MB scroll -36d 95MBscroll -90d 91mb
   
   
   same Index
   ==> besser: ich bin 1.1.2005 oben scrolle runter und bin dort auch P*A*R*T*Y
   ==> kann SOMIT besser die richtige Ausgabe finden und muss nicht ewig scrollen
   ==> DO IT!!
   BETTER 2 STEP NAVIGATION
   unten 5.5.2015 HOME => Scroll Tiles newest => HOME GOTO TOP
   
   footerActivityIndicator for bottom cells no more needed saves ~70LInes
   SNAPP SCROLLING (IF WORKS) SAVES ~40LINES
   
   @next Refactoring: https://developer.apple.com/documentation/uikit/views_and_controls/collection_views/implementing_modern_collection_views
    * pro: less Memory all in one
    * con: no experiance now, no time, 2023's implementation seam to work an is maintainable
   */
  // MARK: - UI Components / Vars
  
  var carouselController: IssueCarouselCVC
  var tilesController: IssueTilesCVC
  var wasUp = true
  
  var carouselControllerCell: UITableViewCell
  var tilesControllerCell: UITableViewCell
  
  lazy var togglePdfButton: Button<ImageView> = {
    let imageButton = Button<ImageView>()
    imageButton.pinSize(CGSize(width: 50, height: 50))
    imageButton.buttonView.hinset = 0.18
    imageButton.buttonView.color = Const.Colors.iconButtonInactive
    imageButton.buttonView.activeColor = Const.Colors.iconButtonActive
    imageButton.accessibilityLabel = "Ansicht umschalten"
    imageButton.isAccessibilityElement = true
    imageButton.onPress(closure: onPDF(sender:))
    imageButton.layer.cornerRadius = 25
    imageButton.backgroundColor = Const.Colors.fabBackground
    imageButton.buttonView.name = self.isFacsimile ? "mobile-device" : "newspaper"
    return imageButton
  }()
  
  var btnLeftConstraint: NSLayoutConstraint?
  
  // MARK: - Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = .black
    self.tableView.showsVerticalScrollIndicator = false
    self.tableView.showsHorizontalScrollIndicator = false
    
    if let ncView = self.navigationController?.view {
      ncView.addSubview(togglePdfButton)
      btnLeftConstraint = pin(togglePdfButton.centerX, to: ncView.left, dist: 50)
      pin(togglePdfButton.bottom, to: ncView.bottomGuide(), dist: -65)
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    setNeedsStatusBarAppearanceUpdate()
  }
  
  public override func viewWillDisappear(_ animated: Bool) {
    togglePdfButton.isHidden = true
    super.viewWillDisappear(animated)
  }
  
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    togglePdfButton.showAnimated()
  }
  
  
  // MARK: - Table view data source
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    // #warning Incomplete implementation, return the number of sections
    return 1
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    // #warning Incomplete implementation, return the number of rows
    return 2
  }
  
  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return self.view.frame.size.height
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    return indexPath.row == 0 ? carouselControllerCell : tilesControllerCell
  }
  
  
  public init(service: IssueOverviewService, feederContext: FeederContext) {
    //    self.service = service
    carouselController = IssueCarouselCVC(service: service)
    tilesController = IssueTilesCVC(service: service)
    self.feederContext = feederContext
    
    carouselControllerCell = UITableViewCell()
    tilesControllerCell = UITableViewCell()
    
    super.init(style: .plain)
    
    self.addChild(carouselController)
    self.addChild(tilesController)
    
    carouselControllerCell.contentView.addSubview(carouselController.view)
    pin(carouselController.view, to: carouselControllerCell)
    
    tilesControllerCell.contentView.addSubview(tilesController.view)
    pin(tilesController.view, to: tilesControllerCell)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - UIScrollViewDelegate (and Helper)
extension HomeTVC {

  @discardableResult
  fileprivate func verifyUp() -> Bool {
    guard let scrollView = self.tableView else { return wasUp }
    wasUp = scrollView.contentOffset.y < self.view.frame.size.height*0.7
    return wasUp
  }
  
  override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    verifyUp()
  }
  
  open override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    snapCell()
  }
  
  open override func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
    snapCell()
  }

  func snapCell() {
    if wasUp && self.tableView.contentOffset.y > self.view.frame.size.height*0.15 {
      scroll(up: false)
    } else if !wasUp && self.tableView.contentOffset.y > self.view.frame.size.height*0.85 {
      scroll(up: false)
    }
    else {
      scroll(up: true)
    }
  }
  
  func scroll(up:Bool){
    self.tableView.scrollToRow(at:  IndexPath(row: up ? 0 : 1, section: 0),
                               at: .top,
                               animated: true)
  }
}

// MARK: - PDF App View Switching
extension HomeTVC {
  func onPDF(sender:Any){
    self.isFacsimile = !self.isFacsimile
    
    if let imageButton = sender as? Button<ImageView> {
      imageButton.buttonView.name = self.isFacsimile ? "mobile-device" : "newspaper"
      imageButton.buttonView.accessibilityLabel = self.isFacsimile ? "App Ansicht" : "Zeitungsansicht"
    }
    self.tilesController.reloadVisibleCells()
    self.carouselController.reloadVisibleCells()
  }
}

// MARK: - Tab Home handling
extension HomeTVC {
  func onHome(){
    if verifyUp() {
      self.tilesController.collectionView
        .scrollToItem(at: IndexPath(row: 0, section: 0),
                      at: .top,
                      animated: false)
      self.carouselController.collectionView
        .scrollToItem(at: IndexPath(row: 0, section: 0),
                      at: .centeredHorizontally,
                      animated: true)
    }
    else {
      self.scroll(up: true)
    }
  }
}

extension HomeTVC: OpenIssueDelegate {
  func openIssue(_ issue: StoredIssue) {
    ///How to prevent multiple open?
    ///already pushed => no problem
    ///3 downloads in Progress => first downloaded? n/ last clicked?
    ///previously first clicked was used so do it again
    ///What happen if download fail? => Nothing another tap may download and open a issue
    ///QUESTIONS
    ///should/can i handle massive multiple downloads?
    ///should i allow?
    ///YES: Which one is selected? What if selected is no reference here?
    ///if  not what happen if i only have
    
    let issueInfo = IssueDisplayService(feederContext: feederContext,
                                    issue: issue)
    loadingIssueInfos.append(issueInfo)
    issueInfo.showIssue(pushDelegate: self)
  }
}

extension HomeTVC: PushIssueDelegate {
  func push(_ viewController: UIViewController, issueInfo: IssueDisplayService) {
    loadingIssueInfos.removeAll(where: { $0 == issueInfo })
    if navigationController?.topViewController != self {
      log("skip pushing: \(viewController) since another is already pushed. the other: \(String(describing: navigationController?.topViewController))")
      return
    }
    self.issueInfo = issueInfo
    self.navigationController?.pushViewController(viewController, animated: true)
  }
}
