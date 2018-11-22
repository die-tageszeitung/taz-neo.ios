//
//  PageCollectionVC.swift
//
//  Created by Norbert Thies on 10.09.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit

fileprivate var countVC = 0

open class PageCollectionVC<View: UIView>: UIViewController, UICollectionViewDelegate,
  UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIScrollViewDelegate {
  
  class PageCell: UICollectionViewCell {
    var view: View?
  }
  
  open var collectionView: UICollectionView!

  open var provider: ((Int,View?)->View)? = nil
  
  /// inset from top/bottom/left/right as factor to min(width,height)
  open var inset = 0.025
  
  fileprivate var initialIndex: Int?
  fileprivate var lastIndex: Int?
  fileprivate var cvSize: CGSize { return self.collectionView.bounds.size }

  open var index: Int? {
    get {
      let wbounds = self.view.bounds
      let center = CGPoint(x: wbounds.midX, y: wbounds.midY) + collectionView.contentOffset
      let ipath = collectionView.indexPathForItem(at:center)
      return ipath?.item
    }
    set {
      if let v = newValue {
        if let _ = self.index { scrollto(v) }
        else { initialIndex = v }
      }
    }
  }
  
  open var count: Int = 0 {
    didSet { if collectionView != nil { collectionView.reloadData() } }
  }
  
  private var reuseIdent: String = { countVC += 1; return "PageCell\(countVC)" }()
  
  public init() { super.init(nibName: nil, bundle: nil) }
  
  public required init?(coder: NSCoder) { super.init(coder: coder) }
  
  open func viewProvider(provider: @escaping (Int,View?)->View) {
    self.provider = provider
  }
  
  open func scrollto(_ index: Int, animated: Bool = false) {
    let ipath = IndexPath(item: index, section: 0)
    collectionView.scrollToItem(at: ipath, at: .centeredHorizontally, animated: animated)
  }

  // MARK: - Life Cycle

  override open func loadView() {
    super.loadView()
    let flowLayout = UICollectionViewFlowLayout()
    flowLayout.scrollDirection = .horizontal
    collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
    collectionView.translatesAutoresizingMaskIntoConstraints = false
    self.view.addSubview(collectionView)
    NSLayoutConstraint.activate([
      collectionView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
      collectionView.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor),
      collectionView.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor),
      collectionView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor),
      ])
    collectionView.register(PageCell.self, forCellWithReuseIdentifier: reuseIdent)
    collectionView.delegate = self
    collectionView.dataSource = self
    collectionView.isPagingEnabled = true
  }
  
  open override func viewDidLoad() {
    super.viewDidLoad()
    if count != 0 { collectionView.reloadData() }
  }
  
  // TODO: transition/rotation better with collectionViewLayout subclass as described in:
  // https://www.matrixprojects.net/p/uicollectionviewcell-dynamic-width/
  open override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
    super.willTransition(to: newCollection, with: coordinator)
    coordinator.animate(alongsideTransition: nil) { [weak self] ctx in
      self?.collectionView.collectionViewLayout.invalidateLayout()
      self?.center()
    }
  }
  
  // MARK: - UICollectionViewDataSource
  
  open func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }
  
  open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return self.count
  }
  
  open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdent,
                                                     for: indexPath) as? PageCell {
      if let idx = initialIndex { initialIndex = nil; scrollto(idx) }
      if let provider = self.provider {
        let page = provider(indexPath.item, cell.view)
        if cell.view !== page {
          if let v = cell.view {
            v.removeFromSuperview()
          }
          cell.view = page
          cell.addSubview(page)
          page.translatesAutoresizingMaskIntoConstraints = false
          NSLayoutConstraint.activate([
            page.topAnchor.constraint(equalTo: cell.topAnchor),
            page.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            page.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            page.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
          ])
        }
        return cell
      }
    }
    return PageCell()
  }
  
  // MARK: - UICollectionViewDelegateFlowLayout
  
  private var margin: CGFloat {
    let s = cvSize
    return min(s.height, s.width) * CGFloat(inset)
  }
  
  private var cellsize: CGSize {
    let s = cvSize
    return CGSize(width: s.width - 2*margin, height: s.height - 2*margin)
  }
  
  public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                             sizeForItemAt indexPath: IndexPath) -> CGSize {
    debug("\(cellsize)")
    return cellsize
  }
  
  public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                           insetForSectionAt section: Int) -> UIEdgeInsets {
    let m = margin
    return UIEdgeInsets(top: m, left: m, bottom: m, right: m)
  }
  
  public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                              minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
    return 0
  }
  
  public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
    return 2*margin
  }
  
  // MARK: - UIScrollViewDelegate
 
  fileprivate func center() {
    var idx: Int?
    if let i = index { idx = i }
    else if let l = lastIndex { idx = l }
    if let i = idx { self.scrollto(i, animated: true) }
  }
  
  fileprivate var isDecelerating = false
  
  public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    isDecelerating = false
  }
  
  public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    if let idx = index { lastIndex = idx }
  }

  public func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
    isDecelerating = true
  }

  public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    //center()
  }
  
  public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    //if !isDecelerating { center() }
  }
  
} // PageCollectionVC

