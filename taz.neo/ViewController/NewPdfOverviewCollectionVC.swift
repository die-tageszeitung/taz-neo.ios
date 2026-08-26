//
//  NewPdfOverviewCollectionVC.swift
//  taz.neo
//
//  Created for new PDF menu with animated header and switchable list/page mode.
//

import UIKit
import NorthLib

/// Enum for the overview menu mode
public enum PdfOverviewMode {
  case list
  case pages
}

/// New overview menu with animated shrinking header and two switchable modes:
/// - List mode: 2 cell types (like LMdSliderContentVC)
/// - Pages mode: 1 cell type (like PdfOverviewCollectionVC)
public class NewPdfOverviewCollectionVC: UICollectionViewController, UIStyleChangeDelegate {
  
  @Default("isPdfPageMode")
  public var isPdfPageMode: Bool {
    didSet {
      guard oldValue != isPdfPageMode else { return }
      let scroll = collectionView.contentInset.top + collectionView.contentOffset.y > 0
      let currentSection = collectionView.indexPathsForVisibleItems.min()?.section
      applyPdfPageMode()
      collectionView.reloadData()
      collectionView.layoutIfNeeded()
      guard scroll else {
        scrollViewDidScroll(collectionView)
        return
      }
      guard let currentSection else { return }
      ///dirty hack to prevent scroll to far up on change due indexPathsForVisibleItems.min returns slightly out of visible items
      let targetSection = min(currentSection, collectionView.numberOfSections)
      let targetOffset
      = (collectionView.collectionViewLayout as? PdfMenuLayout)?.offset(forSection: targetSection) ?? 0.0
      collectionView.setContentOffset(CGPoint(x: 0, y: targetOffset), animated: false)
    }
  }
  
  private func applyPdfPageMode() {
    menuHeaderView.applyMode(isList: !isPdfPageMode)
    applyStyles()
    (collectionView.collectionViewLayout as? PdfMenuLayout)?.mode = isPdfPageMode ? .pages : .list
  }
  
  public func applyStyles() {
    let dark = isPdfPageMode || Defaults.darkMode
    
    headerWrapper.effect = UIBlurEffect(style:
    dark ? .systemThinMaterialDark : .systemUltraThinMaterialLight)
    
    headerWrapper.contentView.backgroundColor
    = dark ? .black.withAlphaComponent(0.35) : .white.withAlphaComponent(0.03)
    headerWrapper.backgroundColor
    = dark ? .black.withAlphaComponent(0.2) : .white.withAlphaComponent(0.03)
    
    self.collectionView.backgroundColor
    = dark ? Const.Colors.darkSecondaryBG : Const.Colors.Light.Taz_BackgroundForms
    
    let textColor = dark ? Const.Colors.iOSDark.label : Const.Colors.iOSLight.label
    menuHeaderView.waitingSpinner.color = textColor
    menuHeaderView.loadInfoLabel.textColor = textColor
    menuHeaderView.dateLabel.textColor = textColor
    menuHeaderView.modeSwitchButton.label.textColor = textColor
    menuHeaderView.listenButton.label.textColor = textColor
    menuHeaderView.modeSwitchButton.imageView.tintColor = textColor
    menuHeaderView.listenButton.imageView.tintColor = textColor
    setNeedsStatusBarAppearanceUpdate()
  }
  
  var pdfModel: NewPdfModel
  
  public var clickCallback: ((PdfModel?, Article?)->())?
  
  // Add further models if needed for articles, etc.
  
  // MARK: - UI Elements
  let menuHeaderView = PdfOverviewMenuHeaderView()
  private let headerWrapper = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
  
  private var menuHeaderHeightConstraint: NSLayoutConstraint?
  private var menuHeaderLeadingConstraint: NSLayoutConstraint?
  
  private let headerMaxHeight: CGFloat = 285
  private var headerMinHeight: CGFloat = 95 {
    didSet {
      log(">> headerMinHeight updated to \(headerMinHeight) former: \(oldValue)")
    }
  }

  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    applyStyles()
    self.view.doLayout()
    calculateHeader()
  }
  
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if headerMinHeight < 50 { calculateHeader() }
  }
  
  public override func loadView() {
    super.loadView()
    applyPdfPageMode()
  }
  
  // MARK: - Initializers
  init(pdfModel: NewPdfModel) {
    self.pdfModel = pdfModel
    menuHeaderView.dateLabel.attributedText
    = NSAttributedString(pdfModel.title, fontSize: Const.Size.SmallerFontSize, lineHeight: 20)
    let layout = PdfMenuLayout(pdfModel: pdfModel)
    layout.sectionInset = UIEdgeInsets(top: PdfDisplayOptions.Overview.sideSpacing,
                                       left: 8.0,
                                       bottom: PdfDisplayOptions.Overview.sideSpacing,
                                       right: PdfDisplayOptions.Overview.sideSpacing)
    layout.minimumLineSpacing = 0
    layout.minimumInteritemSpacing = PdfDisplayOptions.Overview.interItemSpacing - 0.5//fix misscalculation bug
    layout.scrollDirection = .vertical
    super.init(collectionViewLayout: layout)
    _ = pdfModel.thumbnail(atIndex: 0) { [weak self] image in
      DispatchQueue.main.async {
        self?.menuHeaderView.coverImageView.image = image
      }
    }
    if pdfModel.issueInfo?.issue.isComplete == true { return }
    menuHeaderView.isLoading = true
    Notification.receive("issue") { [weak self] notification in
      pdfModel.prepareData()
      (self?.collectionView.collectionViewLayout as? PdfMenuLayout)?.forceUpdate = true
      self?.collectionView.collectionViewLayout.invalidateLayout()
      self?.collectionView.layoutIfNeeded() 
      self?.menuHeaderView.isLoading = false
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - View Lifecycle
  public override func viewDidLoad() {
    super.viewDidLoad()
    setupMenuHeader()
    setupCollectionView()
  }
  
  
  private func setupMenuHeader() {
    headerWrapper.translatesAutoresizingMaskIntoConstraints = false
    menuHeaderView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(headerWrapper)
    headerWrapper.contentView.addSubview(menuHeaderView)
    menuHeaderHeightConstraint = menuHeaderView.heightAnchor.constraint(equalToConstant: headerMaxHeight + 21)
    menuHeaderLeadingConstraint
    = menuHeaderView.leadingAnchor.constraint(equalTo: headerWrapper.safeAreaLayoutGuide.leadingAnchor,
                                              constant: PdfDisplayOptions.Overview.sideSpacing)
    NSLayoutConstraint.activate([
      headerWrapper.topAnchor.constraint(equalTo: view.topAnchor),
      headerWrapper.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      headerWrapper.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      
      menuHeaderView.topAnchor.constraint(equalTo: headerWrapper.safeAreaLayoutGuide.topAnchor, constant:   0),///negative values have no effect
      
      menuHeaderView.trailingAnchor.constraint(equalTo: headerWrapper.trailingAnchor),
      menuHeaderView.bottomAnchor.constraint(equalTo: headerWrapper.bottomAnchor, constant: -2),
      menuHeaderLeadingConstraint!,
      menuHeaderHeightConstraint!
    ])
    collectionView.contentInset.top = headerMaxHeight
    collectionView.setContentOffset(CGPoint(x: 0, y: -headerMaxHeight), animated: false)
    
    // Set initial header data
    menuHeaderView.dateLabel.attributedText
    = NSAttributedString(pdfModel.title, fontSize: Const.Size.SmallerFontSize, lineHeight: 20)
    menuHeaderView.applyMode(isList: !isPdfPageMode)
    
    
    menuHeaderView.modeSwitchButton.onTapping {[weak self] _ in
      self?.isPdfPageMode.toggle()
    }
    
    _ = pdfModel.thumbnail(atIndex: 0) { [weak self] image in
      DispatchQueue.main.async {
        self?.menuHeaderView.coverImageView.image = image
      }
    }
    applyStyles()
    menuHeaderView.coverImageView.onTapping {[weak self] _ in
      guard let self else { return }
      if isPdfPageMode,
        pdfModel.currentPage != 0 {
        pdfModel.currentPage = 0
        clickCallback?(pdfModel, nil)
        return
      }
      if collectionView.contentOffset.y + collectionView.contentInset.top + 20 > 0 {
        collectionView.scrollToItem(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        return
      }
      parentViewController?.navigationController?.popToRootViewController(animated: true)
    }
  }
  
  private func setupCollectionView() {
    collectionView.backgroundColor = .white
    collectionView.register(PdfPageCell.self,
                            forCellWithReuseIdentifier: PdfPageCell.reuseIdentifier)
    collectionView.register(PdfArticleCell.self,
                            forCellWithReuseIdentifier: PdfArticleCell.reuseIdentifier)
    collectionView.register(PdfSectionHeaderView.self,
                            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                            withReuseIdentifier: PdfSectionHeaderView.reuseIdentifier)
    collectionView.showsVerticalScrollIndicator = false
    collectionView.showsHorizontalScrollIndicator = false
  }
  
  private func calculateHeader() {
    let leftCellWidth = collectionView.frame.size.width * Const.Size.taz.Slider.xLeft
    let imageHeight = leftCellWidth / Const.Size.PageAspectRatio
    let verticalPadding: CGFloat = 13.0
    ///min header image width depends on: headerMinHeight
    headerMinHeight = imageHeight + verticalPadding
  }
  
  // MARK: - Scroll for Header Animation
  public override func scrollViewDidScroll(_ scrollView: UIScrollView) {
    // Animate header height based on scroll offset
    let offset
    = scrollView.contentOffset.y
    + scrollView.adjustedContentInset.top
    + (isPdfPageMode ? 0 : 40)/// Adj#1: Header height, neg. values increase header total height
    menuHeaderHeightConstraint?.constant = max(headerMinHeight, headerMaxHeight - offset)
    if isPdfPageMode {
      menuHeaderView.coverBottomConstraint?.constant = min(30, offset/5 ) - 37.5
      menuHeaderView.pageLabel.alpha = max (0, 1 - offset / 80)
      collectionView.contentInset.top = headerMaxHeight
    }
    else {
      menuHeaderView.coverBottomConstraint?.constant = min(-1.5, offset/5) - 6
      menuHeaderView.pageLabel.alpha = 0
      collectionView.contentInset.top = headerMaxHeight - 45
    }
  }
    
  // MARK: - UICollectionViewDataSource
  public override func numberOfSections(in collectionView: UICollectionView) -> Int {
    // PdfMenuLayout expects one section per pdf page in both modes
    return pdfModel.sectionContent.count
  }
  
  public override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    if isPdfPageMode {
      return 1
    } else {
      return (pdfModel.sectionContent.valueAt(section)?.articles.count ?? -1) + 1
    }
  }
  
  public override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    (cell as? PdfPageCell)?.configure(pageMode: isPdfPageMode)
  }
  
  public override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    guard let sectionContent = pdfModel.sectionContent.valueAt(indexPath.section) else {
      return UICollectionViewCell()
    }
    
    if indexPath.row == 0,
      let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PdfPageCell.reuseIdentifier,
                                                    for: indexPath) as? PdfPageCell {
      if indexPath.section == 0 && isPdfPageMode {
        return cell ///empty cell 0 height comes from Layout!
      }
      
      let isAdPage = sectionContent.page.isAdvertisement
      cell.pagina = isAdPage ? nil : sectionContent.page.pagina
      cell.listPrefix = isAdPage ? nil : "Seite"
      cell.pageRessort = sectionContent.page.title
      ///Warning: in list mode pano page is fully visible and horizontally centered
      let isPdfPanoPage = sectionContent.page.type == .double && isPdfPageMode
      cell.imageAspectConstraint?.isActive = !isPdfPanoPage
      cell.pageImageView.contentMode = isPdfPanoPage ? .scaleToFill : .scaleAspectFit
      cell.pageImageView.image =  pdfModel.thumbnail(atIndex: indexPath.section, finishedClosure: { (img) in
        onMain { cell.pageImageView.image = img  }
      })
      return cell
    }
    else if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PdfArticleCell.reuseIdentifier,
                                                          for: indexPath) as? PdfArticleCell,
            let sectionContent = pdfModel.sectionContent.valueAt(indexPath.section),
            let article = sectionContent.articles.valueAt(indexPath.row - 1) {/// row 0 is the Page itself
      cell.article = article
      cell.bottomBorder.isHidden = indexPath.row > sectionContent.articles.count - 1
      return cell
    }
    return UICollectionViewCell()
  }
  
  public override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    var art: Article?
    if indexPath.row > 0 {
      let sectionContent = pdfModel.sectionContent.valueAt(indexPath.section)
      art = sectionContent?.articles.valueAt(indexPath.row - 1)
    }
    pdfModel.currentPage = indexPath.section
    clickCallback?(pdfModel, art)
  }
}

extension NewPdfOverviewCollectionVC: UICollectionViewDelegateFlowLayout {
  // MARK: - Supplementary Views
  public override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
    guard kind == UICollectionView.elementKindSectionHeader,
          let header = collectionView.dequeueReusableSupplementaryView(
      ofKind: kind,
      withReuseIdentifier: PdfSectionHeaderView.reuseIdentifier,
      for: indexPath) as? PdfSectionHeaderView else {
      return UICollectionReusableView()
    }
    header.configure(with: pdfModel.sectionContent.valueAt(indexPath.section)?.sectionName,
                     pageMode: isPdfPageMode)
    header.onTapping {[weak self] _ in
      guard let self else { return }
      pdfModel.currentPage = indexPath.section
      clickCallback?(pdfModel, nil)
    }
    return header
  }
}
