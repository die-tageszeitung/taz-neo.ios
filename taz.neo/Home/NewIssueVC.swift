//
//  NewIssueVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 30.01.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/**
 Discussion:
 
use issueCarousel vs implement UICollectionViewController
+ use a lot of existing
- a lot of existing overhead and refactorable stuff come within
 
 UICollectionViewController
 + free of Altlasteb
 - a lot of things already implemented has to be used
 */

class NewIssueVC: PageCollectionVC {
  
  var service: IssueOverviewService
  
  
//  override var collectionView:PageCollectionView? = CarouselView()

  var issueCarouselLabelWrapperHeight = 0.0
  
  var verticalPaddings: CGFloat { get {
    let insets = self.navigationController?.view.safeAreaInsets ?? UIWindow.safeInsets
    return 42 + insets.top + insets.bottom
  }}
  
  private func updateCarouselSize(_ newSize:CGSize){
    let size
      = newSize != .zero
      ? newSize
      : CGSize(width: UIWindow.size.width,
               height: UIWindow.size.height
               - verticalPaddings)
    let availableH = size.height - 20 - self.issueCarouselLabelWrapperHeight
    let useableH = min(730, availableH) //Limit Height (usually on High Res & big iPad's)
    let availableW = size.width
    let defaultPageRatio:CGFloat = 0.670219
    let maxZoom:CGFloat = 1.3
    let maxPageWidth = defaultPageRatio * useableH / maxZoom
    let relPageWidth = maxPageWidth/availableW
    let relativePageWidth = min(0.6, relPageWidth*0.99)//limit to prevent touch
    (self.collectionView as? CarouselView)?.relativePageWidth = relativePageWidth
    (self.collectionView as? CarouselView)?.relativeSpacing = min(0.12, 0.2*relPageWidth/0.85)
    let maxHeight = size.width * relativePageWidth * 1.3 / defaultPageRatio
    let padding = (size.height - maxHeight)/2
//    (self.collectionView as? CarouselView).labelTopConstraintConstant = 0 - padding
//    self.statusBottomConstraint?.constant = padding - 36
  }
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.collectionView?.backgroundColor = .black
    updateCarouselSize(.zero)
    if let cfl = self.collectionView?.collectionViewLayout as? CarouselFlowLayout {
      cfl.onLayoutChanged{   [weak self]  newSize in
        self?.updateCarouselSize(newSize)
      }
    }
//    viewProvider { [weak self] (index, oview) in
//      let moment = oview as? MomentView ?? MomentView()
//      moment.image = self?.service.image(for: index)
//      return moment
//    }
    count = service.issueDates.count
  }
  
  public init(service: IssueOverviewService) {
    self.service = service
    super.init()
    collectionView = CarouselView()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
}
