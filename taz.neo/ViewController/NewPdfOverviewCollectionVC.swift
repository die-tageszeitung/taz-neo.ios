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
      menuHeaderView.applyMode(isList: !isPdfPageMode)
      applyStyles()
      (collectionView.collectionViewLayout as? PdfMenuLayout)?.mode = isPdfPageMode ? .pages : .list
    }
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
  
  public var clickCallback: ((CGRect, PdfModel?, Article?)->())?
  
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
  
  // MARK: - Initializers
  init(pdfModel: NewPdfModel) {
    self.pdfModel = pdfModel
    let layout = PdfMenuLayout(pdfModel: pdfModel)
    super.init(collectionViewLayout: layout)
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
    // Register all relevant cell types for PdfMenuLayout
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
    let imageHeight = leftCellWidth / 0.64
    //self.view.safeAreaInsets
    let verticalPadding: CGFloat = 13.0  
    headerMinHeight = imageHeight + verticalPadding
  }
  
  // MARK: - Scroll for Header Animation
  public override func scrollViewDidScroll(_ scrollView: UIScrollView) {
    // Animate header height based on scroll offset
    let offset
    = scrollView.contentOffset.y
    + scrollView.adjustedContentInset.top
    + (isPdfPageMode ? -14 : 5)
    menuHeaderHeightConstraint?.constant = max(headerMinHeight, headerMaxHeight - offset)
    if isPdfPageMode {
      menuHeaderView.coverBottomConstraint?.constant = min(0, offset / 5 - 8) - 16
      menuHeaderView.pageLabel.alpha = max (0, 1 - offset / 80)
    }
    else {
      menuHeaderView.coverBottomConstraint?.constant = -8
      menuHeaderView.pageLabel.alpha = 0
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
      
      let isAdPage = !sectionContent.page.hasArticles
      cell.pagina = isAdPage ? nil : sectionContent.page.pagina
      cell.listPrefix = isAdPage ? nil : "Seite"
      cell.pageRessort = sectionContent.page.title
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
      return cell
    }
    
/*
      cell.label.boldContentFont(size: 14.0)
      let attributedText = NSMutableAttributedString()

      if let page = (item as? ZoomedPdfPageImage)?.pageReference?.pagina {
        let font
        = [NSAttributedString.Key.font:
            Const.Fonts.contentFont(size: Const.Size.SmallerFontSize)]
        attributedText.append(NSAttributedString(string: "\(page) ",
                                                 attributes: font))
      }
      if let pageTitle = item.pageTitle {
        let font
        = [NSAttributedString.Key.font:
            Const.Fonts.titleFont(size: Const.Size.SmallerFontSize)]
        attributedText.append(NSAttributedString(string: "\(pageTitle) ",
                                                 attributes: font))
      }
      cell.label.attributedText = attributedText
      cell.label.textColor = Const.Colors.appIconGrey
      return cell
    }
    /// **LIST MODE**
    guard let sectData = pdfModel.sectionContent.valueAt(indexPath.section) else {
      return UICollectionViewCell()
    }
    ///row zero for page
    if indexPath.row == 0 {
      guard let cell = collectionView
        .dequeueReusableCell(withReuseIdentifier: Self.listPageCellIdentifier,
                             for: indexPath) as? PdfPageCell else {
        return UICollectionViewCell()
      }
      cell.pageImageView.image = sectData.page.facsimile?.image(dir: pdfModel.issueInfo?.issue.dir)
      cell.pageLabel.text = sectData.page.pagina
      return cell
    }
    
    guard let cell = collectionView
      .dequeueReusableCell(withReuseIdentifier: Self.listArticleCellIdentifier,
                           for: indexPath) as? PdfArticleCell else {

    }
              */
    return UICollectionViewCell()
  }
  
  public override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let attributes = collectionView.layoutAttributesForItem(at: indexPath)
    var sourceFrame = CGRect.zero
    if let attr = attributes {
      sourceFrame = self.collectionView.convert(attr.frame, to: self.collectionView.superview?.superview)
    }
    var art: Article?
    if indexPath.row > 0 {
      let sectionContent = pdfModel.sectionContent.valueAt(indexPath.section),
      art = sectionContent?.articles.valueAt(indexPath.row - 1)
    }
    pdfModel.currentPage = indexPath.section
    clickCallback?(sourceFrame, pdfModel, art)
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
    return header
  }
  
  // MARK: - UICollectionViewDelegateFlowLayout
  public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
    if collectionViewLayout is PdfMenuLayout {
      return pdfModel.sectionContent.valueAt(section)?.sectionName == nil
        ? CGSize(width: collectionView.bounds.width, height: 0.5) /// nth page of same ressort => just a line
        : CGSize(width: collectionView.bounds.width, height: 40) /// 1st page of a ressort => header with title
    }
    return .zero
  }
}

