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
      collectionView.reloadData()
      updateLayout()
      menuHeaderView.applyMode(isList: !isPdfPageMode)
      applyStyles()
      collectionView.reloadData()
    }
  }
  private var indexShift: Int { isPdfPageMode ? 1 : 0 }
  
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
    menuHeaderView.dateLabel.textColor = textColor
    menuHeaderView.modeSwitchButton.label.textColor = textColor
    menuHeaderView.listenButton.label.textColor = textColor
    menuHeaderView.modeSwitchButton.imageView.tintColor = textColor
    menuHeaderView.listenButton.imageView.tintColor = textColor
    setNeedsStatusBarAppearanceUpdate()
  }
  
  /// Optional: Pass in a model (e.g., PdfModel or other)
  var pdfModel: NewPdfModel {
    didSet {
      menuHeaderView.dateLabel.attributedText
      = NSAttributedString(pdfModel.title, fontSize: Const.Size.SmallerFontSize, lineHeight: 20)
      _ = pdfModel.thumbnail(atIndex: 0) { [weak self] image in
        DispatchQueue.main.async {
          self?.menuHeaderView.coverImageView.image = image
        }
      }
    }
  }
  
  public var clickCallback: ((CGRect, PdfModel?)->())?
  
  // Add further models if needed for articles, etc.
  
  // MARK: - UI Elements
  let menuHeaderView = PdfOverviewMenuHeaderView()
  private let headerWrapper = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
  
  private var menuHeaderHeightConstraint: NSLayoutConstraint?
  private var menuHeaderLeadingConstraint: NSLayoutConstraint?
  
  private let headerMaxHeight: CGFloat = 250
  private var headerMinHeight: CGFloat = 95 {
    didSet {
      log(">> headerMinHeight updated to \(headerMinHeight) former: \(oldValue)")
    }
  }

  // MARK: - ???
  private var fixScrollPos:Bool = false
  
  // MARK: - Cell Identifiers
  private static let listPageCellIdentifier = "ListPageCell"
  private static let listArticleCellIdentifier = "ListArticleCell"
  private static let pageCellIdentifier = "PageCell"
  
  public override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    applyStyles()
    updateLayout()
    calculateHeader()
//    menuHeaderLeadingConstraint?.constant =
//    self.collectionView.layoutMargins.left
//    + ((self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset.left ?? 0)
  }
  
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if headerMinHeight < 50 { calculateHeader() }
  }
  
  // MARK: - Initializers
  init(pdfModel: NewPdfModel) {
    self.pdfModel = pdfModel
    super.init(collectionViewLayout: UICollectionViewLayout())
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
    menuHeaderHeightConstraint = menuHeaderView.heightAnchor.constraint(equalToConstant: headerMaxHeight)
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
  }
  
  private func setupCollectionView() {
    collectionView.backgroundColor = .white
    // Register all relevant cell types
    collectionView?.register(PdfOverviewCvcCell.self, forCellWithReuseIdentifier: Self.pageCellIdentifier)
    collectionView.register(LMdPageImageCell.self, forCellWithReuseIdentifier: Self.listPageCellIdentifier)
    collectionView.register(LMdPageArticleCell.self, forCellWithReuseIdentifier: Self.listArticleCellIdentifier)
    collectionView.register(SectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: SectionHeaderView.reuseIdentifier)
    collectionView.register(CvSeperator.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter.self ,
                withReuseIdentifier: CvSeperator.reuseIdentifier)
    
    collectionView?.showsVerticalScrollIndicator = false
    collectionView?.showsHorizontalScrollIndicator = false
  }
  
  private var currentLayout: UICollectionViewLayout {
    if isPdfPageMode {
      let layout = TwoColumnUICollectionViewFlowLayout(pdfModel: pdfModel)
      layout.sectionInset = UIEdgeInsets(top: PdfDisplayOptions.Overview.sideSpacing,
                                         left: 8.0,
                                         bottom: PdfDisplayOptions.Overview.sideSpacing,
                                         right: PdfDisplayOptions.Overview.sideSpacing)
      /// reduced currently to 0 because label not filled
      /// possible data may come from datamodel, can be: titel, Seite 1 // taz 2, Seite 14 //  die wahrheit; S. 20
      /// Daten sind da, da die PDF diese enthällt
      layout.minimumLineSpacing = PdfDisplayOptions.Overview.rowSpacing
      layout.minimumInteritemSpacing = PdfDisplayOptions.Overview.interItemSpacing - 0.5//fix misscalculation bug
      layout.scrollDirection = .vertical
      return layout
    }
    
    let layout = PdfMenuListFlowLayout()
    layout.minimumInteritemSpacing = 16.0
    layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 10, right: 15)
    layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
    return layout
  }
  
  private func calculateHeader() {
    let leftCellWidth = collectionView.frame.size.width * Const.Size.taz.Slider.xLeft
    let imageHeight = leftCellWidth / 0.64
    //self.view.safeAreaInsets
    let verticalPadding: CGFloat = 13.0  
    headerMinHeight = imageHeight + verticalPadding
  }
  
  private func updateLayout() {
    let newLayout = currentLayout
    collectionView.setCollectionViewLayout(newLayout, animated: true)
  }
  
  // MARK: - Scroll for Header Animation
  public override func scrollViewDidScroll(_ scrollView: UIScrollView) {
    // Animate header height based on scroll offset
    let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
    menuHeaderHeightConstraint?.constant = max(headerMinHeight, headerMaxHeight - offset)
  }
    
  // MARK: - UICollectionViewDataSource
  public override func numberOfSections(in collectionView: UICollectionView) -> Int {
    isPdfPageMode ? 1 : pdfModel.pageIndex2page.count
  }
  
  public override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    isPdfPageMode
    ? pdfModel.count - indexShift
    : (pdfModel.pageIndex2article[section]?.count ?? -1) + 1
  }
  
  public override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    if isPdfPageMode {
      let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.pageCellIdentifier, for: indexPath)
      guard let cell = cell as? PdfOverviewCvcCell else { return cell }
      cell.backgroundColor = .systemYellow.withAlphaComponent(0.1)
      cell.imageView.image =  pdfModel.thumbnail(atIndex: indexPath.row + indexShift, finishedClosure: { (img) in
        onMain { cell.imageView.image = img  }
      })
      guard let item = pdfModel.item(atIndex: indexPath.row + indexShift) else {
        return cell
      }
      
      cell.label.boldContentFont(size: 14.0)
      let attributedText = NSMutableAttributedString()

      if let page = (item as? ZoomedPdfPageImage)?.pageReference?.pagina {
        let font
        = [NSAttributedString.Key.font:
            Const.Fonts.tazFont(size: Const.Size.SmallerFontSize)]
        attributedText.append(NSAttributedString(string: "\(page) ",
                                                 attributes: font))
      }
      if let pageTitle = item.pageTitle {
        let font
        = [NSAttributedString.Key.font:
            Const.Fonts.tazFontBold(size: Const.Size.SmallerFontSize)]
        attributedText.append(NSAttributedString(string: "\(pageTitle) ",
                                                 attributes: font))
      }
      cell.label.attributedText = attributedText
      cell.label.textColor = Const.Colors.appIconGrey
      return cell
    }
    
    if indexPath.row == 0 {
      guard let cell = collectionView
        .dequeueReusableCell(withReuseIdentifier: Self.listPageCellIdentifier,
                             for: indexPath) as? LMdPageImageCell else {
        return UICollectionViewCell()
      }
      cell.issueDir = pdfModel.issueInfo?.issue.dir
      cell.page = pdfModel.page(at: indexPath.section)//?? + indexShift??
      return cell
    }
    
    guard let cell = collectionView
      .dequeueReusableCell(withReuseIdentifier: Self.listArticleCellIdentifier,
                           for: indexPath) as? LMdPageArticleCell else {
      return UICollectionViewCell()
    }
    cell.article = pdfModel.articleAt(indexPath: indexPath)
    return cell
  }
  
  public override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let attributes = collectionView.layoutAttributesForItem(at: indexPath)
    var sourceFrame = CGRect.zero
    if let attr = attributes {
      sourceFrame = self.collectionView.convert(attr.frame, to: self.collectionView.superview?.superview)
    }
    pdfModel.index = indexPath.row + indexShift
    clickCallback?(sourceFrame, pdfModel)
  }
}

extension NewPdfOverviewCollectionVC: UICollectionViewDelegateFlowLayout {
  // MARK: - Supplementary Views
  public override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
    if kind == UICollectionView.elementKindSectionHeader,
       let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SectionHeaderView.reuseIdentifier, for: indexPath) as? SectionHeaderView {
      header.label.text = pdfModel.page(at: indexPath.section)?.title
      return header
    }
    else if kind == UICollectionView.elementKindSectionFooter {
      return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: CvSeperator.reuseIdentifier, for: indexPath)
    }
    return UICollectionReusableView()
  }
  
  // MARK: - UICollectionViewDelegateFlowLayout
  public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
    return CGSize(width: collectionView.bounds.width, height: 40)
  }
}

