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
  
  public func applyStyles() {
    headerWrapper.backgroundColor = isPdfPageMode ? Const.Colors.darkSecondaryBG : Const.SetColor.CTBackground.color
    self.view.backgroundColor = isPdfPageMode ? Const.Colors.darkSecondaryBG : Const.SetColor.CTBackground.color
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
  public var pdfModel: PdfModel? {
    didSet {
      menuHeaderView.dateLabel.text = pdfModel?.title
      if let pdfModel = pdfModel {
        pdfModel.thumbnail(atIndex: 0) { [weak self] image in
          DispatchQueue.main.async {
            self?.menuHeaderView.coverImageView.image = image
          }
        }
      }
    }
  }
  // Add further models if needed for articles, etc.
  
  // MARK: - UI Elements
  private let menuHeaderView = PdfOverviewMenuHeaderView()
  private let headerWrapper = UIView()
  private var menuHeaderHeightConstraint: NSLayoutConstraint?
  private let headerMaxHeight: CGFloat = 270
  private let headerMinHeight: CGFloat = 180

  // MARK: - ???
  private var fixScrollPos:Bool = false
  
  // MARK: - Cell Identifiers
  private static let listPageCellIdentifier = "ListPageCell"
  private static let listArticleCellIdentifier = "ListArticleCell"
  private static let pageCellIdentifier = "PageCell"
  
  // MARK: - Initializers
  public init(pdfModel: PdfModel? = nil) {
    self.pdfModel = pdfModel
    let layout = Self.getLayout(isPdfPageMode: false, for: pdfModel) // Start in list mode by default
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
    headerWrapper.addSubview(menuHeaderView)
    menuHeaderHeightConstraint = menuHeaderView.heightAnchor.constraint(equalToConstant: headerMaxHeight)
    NSLayoutConstraint.activate([
      headerWrapper.topAnchor.constraint(equalTo: view.topAnchor),
      headerWrapper.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      headerWrapper.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      
      menuHeaderView.topAnchor.constraint(equalTo: headerWrapper.safeAreaLayoutGuide.topAnchor, constant:   0),///negative values have no effect
      menuHeaderView.leadingAnchor.constraint(equalTo: headerWrapper.safeAreaLayoutGuide.leadingAnchor, constant: 14),
      menuHeaderView.trailingAnchor.constraint(equalTo: headerWrapper.trailingAnchor),
      menuHeaderView.bottomAnchor.constraint(equalTo: headerWrapper.bottomAnchor, constant: -15),
      menuHeaderHeightConstraint!
    ])
    collectionView.contentInset.top = headerMaxHeight
    
    // Set initial header data
    menuHeaderView.dateLabel.text = pdfModel?.title
    menuHeaderView.applyMode(isList: !isPdfPageMode)
    
    menuHeaderView.modeSwitchButton.addTarget(self, action: #selector(didTapModeSwitch), for: .touchUpInside)
    menuHeaderView.listenButton.addTarget(self, action: #selector(didTapListen), for: .touchUpInside)
    
    if let pdfModel = pdfModel {
      pdfModel.thumbnail(atIndex: 0) { [weak self] image in
        DispatchQueue.main.async {
          self?.menuHeaderView.coverImageView.image = image
        }
      }
    }
    applyStyles()
  }
  
  private func setupCollectionView() {
    collectionView.backgroundColor = .white
    // Register all relevant cell types
    collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Self.pageCellIdentifier)
    collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Self.listPageCellIdentifier)
    collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Self.listArticleCellIdentifier)
  }
  
  private static func getLayout(isPdfPageMode: Bool, for pdfModel: PdfModel?) -> UICollectionViewLayout {
    if isPdfPageMode, let pdfModel = pdfModel {
      return TwoColumnUICollectionViewFlowLayout(pdfModel: pdfModel)
    }
    let flowLayout = UICollectionViewFlowLayout()
    flowLayout.scrollDirection = .vertical
    return flowLayout
  }
  
  private func updateLayout() {
    let newLayout = Self.getLayout(isPdfPageMode: isPdfPageMode,
                                         for: pdfModel)
    collectionView.setCollectionViewLayout(newLayout, animated: true)
  }
  
  // MARK: - Scroll for Header Animation
  public override func scrollViewDidScroll(_ scrollView: UIScrollView) {
    // Animate header height based on scroll offset
    let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
    menuHeaderHeightConstraint?.constant = max(headerMinHeight, headerMaxHeight - offset)
  }
    
  // MARK: - Actions
  @objc private func didTapModeSwitch() {
    isPdfPageMode.toggle()
  }
  
  @objc private func didTapListen() {
    // TODO: Implement listen action
  }
  
  // MARK: - UICollectionViewDataSource
  public override func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }
  
  public override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    // Determine count based on mode/model
    return pdfModel?.count ?? 0
  }
  
  public override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    if isPdfPageMode {
      let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.pageCellIdentifier, for: indexPath)
      cell.backgroundColor = .systemYellow.withAlphaComponent(0.1)
      // Configure as page cell (like PdfOverviewCvcCell)
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
}

