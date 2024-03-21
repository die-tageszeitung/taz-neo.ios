//
//  LMdSliderContentVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 11.01.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import UIKit
import NorthUIKit

/// content table for button slider displays pages and articles in a 2 column layout
class LMdSliderContentVC: UIViewController {
  
  fileprivate var pagePressedClosure: ((Page)->())?
  fileprivate var articlePressedClosure: ((Article)->())?
  
  lazy var collectionView:UICollectionView = {
    //setup collectionview layout
    let layout = LMdSliderCVFlowLayout()
    layout.minimumInteritemSpacing = 16.0
    layout.sectionInset = UIEdgeInsets(top: 16, left: 15, bottom: 10, right: 15)
    layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
    
    let cv = UICollectionView(frame: .zero,
                              collectionViewLayout: layout)
    
    //register cell types
    cv.register(LMdPageImageCell.self, 
                forCellWithReuseIdentifier: Self.PageImageCellIdentifier)
    cv.register(LMdPageArticleCell.self,
                forCellWithReuseIdentifier: Self.PageArticleCellIdentifier)
    cv.register(CvSeperator.self,
                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader.self ,
                withReuseIdentifier: Self.SectionSeperatorIdentifier)
    
    //setup data source
    cv.dataSource = self
    cv.delegate = self
    
    return cv
  }()
  
  lazy var header = LMdSliderHeader(frame: CGRect(x: 0,
                                                  y: 0,
                                                  width: Const.Size.ContentSliderMaxWidth,
                                                  height: 180))
  var dataSource: LMdSliderDataModel? {
    didSet {
      collectionView.reloadData()
      header.issueLabel.text = dataSource?.issue.date.stringWith(dateFormat: "MMMM YYYY").prepend(" ")
    }
  }

  func updateScrollPosition(){
    guard let pageIndex
            = dataSource?.pageName2pageIndex[currentPage?.pdf?.name ?? ""] else { return }
    guard let layout = collectionView.collectionViewLayout as? LMdSliderCVFlowLayout,
          let yOffset = layout.offset(forItemAt: IndexPath(item: 0, section: pageIndex))
    else { return }
    //prevent scroll last item to top; prevent uggly scroll behaviour
    
    let yPos = max(0, min(yOffset, collectionView.contentSize.height
                   - collectionView.frame.size.height))
    let halfSeperatorHeight:CGFloat = pageIndex == 0 ? -10 : 18 //remove section >0 seperator offset
    collectionView.setContentOffset(CGPoint(x: 0, y: yPos + halfSeperatorHeight),
                                     animated: false)
  }
  
  var currentPage: Page? {
    didSet {
      header.image = dataSource?.facsimile(for: currentPage)
      if let pagina = currentPage?.pagina {
        header.pageLabel.text = "Seite \(pagina)"
      }
      else {
        header.pageLabel.text = nil
      }
      updateScrollPosition()
    }
  }
  var currentArticle: Article? {
    didSet {
      currentPage = dataSource?.issue.pages?.first(where: { page in
        return currentArticle?.pageNames?.contains{ $0 == page.pdf?.name } ?? false
      })
    }
  }
  fileprivate static let PageImageCellIdentifier = "PageImageCell"
  fileprivate static let PageArticleCellIdentifier = "PageArticleCellCell"
  fileprivate static let SectionSeperatorIdentifier = "SectionSeperatorIdentifier"
}

extension LMdSliderContentVC: UIStyleChangeDelegate{
  public func applyStyles() {
    self.view.backgroundColor = Const.SetColor.MenuBackground.color
    self.collectionView.backgroundColor = Const.SetColor.MenuBackground.color
    if collectionView.superview != nil { self.collectionView.reloadData() }
  }
}

extension LMdSliderContentVC {
  /// Define closure to call when a content label has been pressed
  public func onPagePress(closure: @escaping (Page)->()) {
    pagePressedClosure = closure
  }
  
  public func onArticlePress(closure: @escaping (Article)->()) {
    articlePressedClosure = closure
  }
}

///lifecycle
extension LMdSliderContentVC {
  public override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = Const.SetColor.MenuBackground.color
    
    //setup ui with fixed header
    self.view.addSubview(header)
    self.view.addSubview(collectionView)
    pin(header, toSafe: self.view, exclude: .bottom)
    pin(collectionView, to: self.view, exclude: .top)
    pin(collectionView.top, to: header.bottom)
    registerForStyleUpdates()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    header.doLayout()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    updateScrollPosition()
    super.viewDidAppear(animated)
  }
}

// MARK: - UICollectionViewDataSource
extension LMdSliderContentVC: UICollectionViewDataSource {
  
  func collectionView(_ collectionView: UICollectionView,
                      viewForSupplementaryElementOfKind kind: String,
                      at indexPath: IndexPath) -> UICollectionReusableView {

    let v = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                           withReuseIdentifier: Self.SectionSeperatorIdentifier,
                                                           for: indexPath)
//    print("viewForSupplementaryElementOfKind: \(kind) at: \(indexPath) called")
    return v
  }
  
  func numberOfSections(in collectionView: UICollectionView) -> Int {
    return dataSource?.pageIndex2page.count ?? 0
  }
  
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return (dataSource?.pageIndex2article[section]?.count ?? -1) + 1
  }
  
   func collectionView(_ collectionView: UICollectionView, 
                       cellForItemAt indexPath: IndexPath)
  -> UICollectionViewCell {
    if indexPath.row == 0 {
      guard let cell = collectionView
        .dequeueReusableCell(withReuseIdentifier: Self.PageImageCellIdentifier,
                             for: indexPath) as? LMdPageImageCell else {
        return UICollectionViewCell()
      }
      cell.issueDir = dataSource?.issue.dir
      cell.page = pageAt(indexPath: indexPath)
      return cell
    }
    
    guard let cell = collectionView
      .dequeueReusableCell(withReuseIdentifier: Self.PageArticleCellIdentifier,
                           for: indexPath) as? LMdPageArticleCell else {
      return UICollectionViewCell()
    }
    cell.article = articleAt(indexPath: indexPath)
    return cell
  }
  
}

// MARK: - Helper
extension LMdSliderContentVC {
  func articleAt(indexPath: IndexPath) -> Article? {
    return dataSource?.pageIndex2article[indexPath.section]?.valueAt(indexPath.row-1)
  }
  
  func pageAt(indexPath: IndexPath) -> Page? {
    return dataSource?.pageIndex2page[indexPath.section]
  }
}

extension LMdSliderContentVC:  UICollectionViewDelegateFlowLayout {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    guard let issueDir = dataSource?.issue.dir,
          let page = pageAt(indexPath: indexPath) else { return }
    header.image = page.facsimile?.image(dir: issueDir)
    header.pageLabel.text = "Seite \(page.pagina ?? "")"
    
    if indexPath.row == 0 {
      pagePressedClosure?(page)
    }
    else if let article = articleAt(indexPath: indexPath) {
      articlePressedClosure?(article)
    }
  }
}
