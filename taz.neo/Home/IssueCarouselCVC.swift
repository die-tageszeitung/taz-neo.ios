//
//  NewIssueCVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 30.01.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib


class IssueCarouselCVC: UICollectionViewController {
  
  private static let reuseCellId = "issueCollectionViewCell"
  
  var nextHorizontalSizeClass:UIUserInterfaceSizeClass?
  var service: IssueOverviewService
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Uncomment the following line to preserve selection between presentations
    // self.clearsSelectionOnViewWillAppear = false
    
    // Register cell classes
    self.collectionView!.register(IssueCollectionViewCell.self,
                                  forCellWithReuseIdentifier: Self.reuseCellId)
    self.collectionView.backgroundColor = .black
  }
    
  // MARK: UICollectionViewDataSource
  
  override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }
  
  
  override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return service.issueDates.count
  }
  
  override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: Self.reuseCellId,
      for: indexPath)
    guard let cell = cell as? IssueCollectionViewCell,
          let data = service.cellData(for: indexPath.row) else { return cell }
    cell.date = data.date
    cell.issue = data.issue
    cell.image = data.image
    return cell
  }
  
  // MARK: > Cell Click/Select
  public override func collectionView(_ collectionView: UICollectionView,
                                      didSelectItemAt indexPath: IndexPath) {
    guard let issue = self.service.getIssue(at: indexPath.row) else {
      error("Issue not available try later")
      return
    }
    (parent as? OpenIssueDelegate)?.openIssue(issue)
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    updateCarouselSize(nil)
  }
  
  override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
    nextHorizontalSizeClass = newCollection.horizontalSizeClass
    super.willTransition(to: newCollection, with: coordinator)
  }
  
  public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    updateCarouselSize(size)
  }
  
  public override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
  }
  
  public init(service: IssueOverviewService) {
    self.service = service
    let layout = IssueCarouselFlowLayout()
    layout.scrollDirection = .horizontal
    layout.sectionInset = .zero
    layout.minimumInteritemSpacing = 1000000.0
    
    super.init(collectionViewLayout: layout)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}


extension IssueCarouselCVC {
  func reloadVisibleCells() {
    let vips = self.collectionView.indexPathsForVisibleItems
    for ip in vips {
      _ = self.collectionView.cellForItem(at: ip)
    }
    //is faster tested with iPadOS 16.2 iPad Pro 2 Simulators same
    // Data/environment; code change if false,... Lamdscape
    // reconfigure feels ~1/3 faster
    // @see: https://swiftsenpai.com/development/cells-reload-improvements-ios-15/
    if #available(iOS 15.0, *) {
      self.collectionView.reconfigureItems(at: vips)
    } else {
      UIView.performWithoutAnimation {
        self.collectionView.reloadItems(at: vips)
      }
    }
  }
}

extension IssueCarouselCVC {
  fileprivate func updateCarouselSize(_ newSize:CGSize?){
    guard let layout = self.collectionView.collectionViewLayout as? CarouselFlowLayout else { return }
    let size = newSize ?? self.view.frame.size
    let defaultPageRatio:CGFloat = 0.670219
    
    var sideInset = 0.0
    //https://developer.apple.com/design/human-interface-guidelines/foundations/layout/
    if nextHorizontalSizeClass ?? self.traitCollection.horizontalSizeClass == .compact && size.width < size.height * 0.6 {
      let w = size.width*0.6
      let h = w/defaultPageRatio
      layout.itemSize = CGSize(width: w, height: h)
      layout.minimumLineSpacing //= 60.0
      = size.width*0.155//0.3/2 out of view bei 0.4/2
      sideInset = (size.width - w)/2
    } else {
      //Moments are 660*985
      let h = min(size.height*0.5, 985*UIScreen.main.scale)
      let w = h*defaultPageRatio
      layout.itemSize = CGSize(width: w, height: h)
      layout.minimumLineSpacing //= 60.0
      = w*0.3//0.3/2 out of view bei 0.4/2
      sideInset = (size.width - w)/2
    }
    nextHorizontalSizeClass = nil
    
    self.collectionView.contentInset
    = UIEdgeInsets(top:0,left:sideInset,bottom:0,right:sideInset)
    return
    //
    let maxItmH = 0.6 * size.height //1.3 Zoom 2/3 höhe = 0.66*1/1.3 = 0.46
    //
    
    
    //MAx Scale == 1.3
    //=>
    layout.itemSize = CGSize(width: size.width*0.6, height: size.height*0.5)
    //Screen-w 1170 Moment 912*1363
    //rel page width: 0.77
    layout.minimumLineSpacing = size.width*0.155//0.3/2 out of view bei 0.4/2
    //was ist mit iPad??
    return
    var verticalPaddings: CGFloat { get {
      let insets = self.navigationController?.view.safeAreaInsets ?? UIWindow.safeInsets
      return 42 + insets.top + insets.bottom
    }}
    var issueCarouselLabelWrapperHeight: CGFloat = 120
    
    /* REMOVE! from 1st implementation
     layout.scrollDirection = .horizontal
     layout.itemSize = CGSize(width: 300, height: 400)
     layout.sectionInset = .zero
     layout.minimumLineSpacing = UIScreen.main.bounds.width - 300
     
     
     
     **/
    
    
    //    let size
    //      = newSize != .zero
    //      ? newSize
    //      : CGSize(width: UIWindow.size.width,
    //               height: UIWindow.size.height
    //               - verticalPaddings)
    let siz2e = newSize ?? self.view.frame.size
    
    //    let availableH = size.height - 20 - issueCarouselLabelWrapperHeight
    //    let useableH = min(730, availableH) //Limit Height (usually on High Res & big iPad's)
    //    let availableW = size.width
    let defauletPageRatio:CGFloat = 0.670219
    //    let maxZoom:CGFloat = 1.3
    let maxPageWidth = size.width * 0.5
    //    defaultPageRatio * useableH / maxZoom
    //    let relPageWidth = maxPageWidth/availableW
    //    let relativePageWidth = min(0.6, relPageWidth*0.99)//limit to prevent touch
    //    let relativeSpacing = min(0.12, 0.2*relPageWidth/0.85)
    //    let maxHeight = size.width * relativePageWidth * 1.3 / defaultPageRatio
    let maxHeight = maxPageWidth/defaultPageRatio
    
    //    let padding = (size.height - maxHeight)/2
    //    self.issueCarousel.labelTopConstraintConstant = 0 - padding
    //    self.statusBottomConstraint?.constant = padding - 36
    
    guard let layout = self.collectionView.collectionViewLayout as? CarouselFlowLayout else { return }
    layout.itemSize = CGSize(width: maxPageWidth, height: maxHeight)
  }
  
}
