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
    }
  }
  private var indexShift: Int { isPdfPageMode ? 1 : 0 }
  
  public func applyStyles() {
    headerWrapper.contentView.backgroundColor = UIColor.black.withAlphaComponent(0.35)
//    headerWrapper.alpha = 0.9
//    headerWrapper.tintColor = isPdfPageMode ? .black : Const.SetColor.CTBackground.color
    headerWrapper.backgroundColor = isPdfPageMode ? .black.withAlphaComponent(0.2) : Const.SetColor.CTBackground.color
    self.view.backgroundColor = isPdfPageMode ? Const.Colors.darkSecondaryBG  : Const.SetColor.CTBackground.color
    self.collectionView.backgroundColor = isPdfPageMode ? Const.Colors.darkSecondaryBG  : Const.SetColor.CTBackground.color
    let dark = isPdfPageMode || Defaults.darkMode
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
      menuHeaderView.dateLabel.text = pdfModel.title
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
  
  private let headerMaxHeight: CGFloat = 270
  private let headerMinHeight: CGFloat = 110

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
    menuHeaderLeadingConstraint?.constant =
    self.collectionView.layoutMargins.left
    + ((self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset.left ?? 0)
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
    menuHeaderView.dateLabel.text = pdfModel.title
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
    collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Self.listPageCellIdentifier)
    collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Self.listArticleCellIdentifier)
    
    collectionView?.showsVerticalScrollIndicator = false
    collectionView?.showsHorizontalScrollIndicator = false
  }
  
  private var currentLayout: UICollectionViewLayout {
    if isPdfPageMode {
      let layout = TwoColumnUICollectionViewFlowLayout(pdfModel: pdfModel)
      layout.sectionInset = UIEdgeInsets(top: PdfDisplayOptions.Overview.sideSpacing,
                                         left: PdfDisplayOptions.Overview.sideSpacing,
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
    let flowLayout = UICollectionViewFlowLayout()
    flowLayout.scrollDirection = .vertical
    return flowLayout
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
    return 1
  }
  
  public override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    // Determine count based on mode/model
    return pdfModel.count - indexShift
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
      
      cell.label.boldContentFont()
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
    // For demonstration, alternate cells for list
    if indexPath.row % 2 == 0 {
      let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.listPageCellIdentifier, for: indexPath)
      cell.backgroundColor = .systemBlue.withAlphaComponent(0.1)
      // Configure as page cell (like LMdPageImageCell)
      return cell
    } else {
      let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.listArticleCellIdentifier, for: indexPath)
      cell.backgroundColor = .systemGreen.withAlphaComponent(0.1)
      // Configure as article cell (like LMdPageArticleCell)
      return cell
    }
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

