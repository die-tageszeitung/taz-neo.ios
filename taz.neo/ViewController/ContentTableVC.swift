//
//  ContentTableVC.swift
//
//  Created by Norbert Thies on 24.09.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

public class ContentTableVC: UIViewController, UIGestureRecognizerDelegate,
  UITableViewDelegate,  UITableViewDataSource, UIContextMenuInteractionDelegate {  
  
  // Colors, Fonts and sizes
  static var BackgroundColor = UIColor.white
  static var ShadowColor = UIColor.black
  static var SectionColor = UIColor.rgb(0xd50d2e)
  static var ArticleColor = UIColor.darkGray
  static var DateColor = UIColor.darkGray
  static var IsDarkMode = false
  static var TextFont = UIFont.boldSystemFont(ofSize: 18)
  static var DateTextFont = UIFont.systemFont(ofSize: 14)
  static var CellHeight = CGFloat(30)
  static var ImageWidth = CGFloat(150)
  
  // Setup colors depending on Defaults["colorMode"]
  private func setupColors() {
    if let mode = Defaults.singleton["colorMode"], mode == "dark" {
      Self.IsDarkMode = true
      Self.BackgroundColor = AppColors.Dark.CTBackground
      Self.ShadowColor = UIColor.white
      Self.SectionColor = AppColors.Dark.CTSection
      Self.ArticleColor = AppColors.Dark.CTArticle
      Self.DateColor = AppColors.Dark.CTDate
    }
    else {
      Self.IsDarkMode = false
      Self.BackgroundColor = AppColors.Light.CTBackground
      Self.ShadowColor = UIColor.black
      Self.SectionColor = AppColors.Light.CTSection
      Self.ArticleColor = AppColors.Light.CTArticle
      Self.DateColor = AppColors.Light.CTDate
    }
  }
  
  private func resetColors() {
    setupColors()
    view.backgroundColor = ContentTableVC.BackgroundColor
    issueDateLabel.backgroundColor = UIColor.clear
    issueDateLabel.textColor = ContentTableVC.DateColor
    issueDateLabel.font = ContentTableVC.DateTextFont
    momentView.layer.shadowColor = ContentTableVC.ShadowColor.cgColor
    if ContentTableVC.IsDarkMode {
      contentTableView.indicatorStyle = .white
    }
    else { contentTableView.indicatorStyle = .black }
  }

  /// Perform table view animations
  static var showAnimations = true
  
  // The TableView cell name
  fileprivate let sectionCell = "sectionCell"
  
  // The TableViewCell
  class SectionCell: UITableViewCell {
    
    lazy var cellView: UIView = {
      let view = UIView()
      view.backgroundColor = UIColor.clear
      view.translatesAutoresizingMaskIntoConstraints = false
      return view
    }()
    
    lazy var cellLabel: UILabel = {
      let label = UILabel()
      label.font = ContentTableVC.TextFont
      label.textAlignment = .left
      label.numberOfLines = 1
      label.adjustsFontSizeToFitWidth = true
      label.translatesAutoresizingMaskIntoConstraints = false
      return label
    }()
    
    func setup() {
      self.backgroundColor = UIColor.clear
      addSubview(cellView)
      cellView.addSubview(cellLabel)
      self.selectionStyle = .none
      pin(cellView, to: self)
      pin(cellLabel.left, to: cellView.left)
      pin(cellLabel.right, to: cellView.right)
      pin(cellLabel.centerY, to: cellView.centerY)
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
      super.init(style: style, reuseIdentifier: reuseIdentifier)
      setup()
    }
    required init?(coder aDecoder: NSCoder) {
      super.init(coder: aDecoder)
    }
    
  }
  
  // Outlets
  @IBOutlet weak var momentView: UIImageView!
  @IBOutlet weak var issueDateLabel: UILabel!
  @IBOutlet weak var contentTableView: UITableView!
  
  // momentView constraints
  fileprivate var momentWidth: NSLayoutConstraint?
  fileprivate var momentHeight: NSLayoutConstraint?

  /// The Feeder providing the Issues
  public var feeder: Feeder?
  
  /// The Issue to display
  public var issue: Issue? {  didSet { resetIssue() } }
  
  fileprivate func resetIssue() {
    if let issue = issue, let feeder = feeder, let label = issueDateLabel,
      let tableView = contentTableView {
      label.text = issue.date.gLowerDateString(tz: feeder.timeZone)
      tableView.reloadData() 
    }
  } 
  
  /// The Image to display
  public var image: UIImage? { didSet { resetImage() } }
  
  fileprivate func resetImage() {
    if let image = image, let momentView = momentView {
      momentView.image = image
      momentWidth?.isActive = false
      momentHeight?.isActive = false
      momentWidth = momentView.pinWidth(ContentTableVC.ImageWidth)
      let factor = image.size.width / ContentTableVC.ImageWidth
      let height = image.size.height / factor
      momentHeight = momentView.pinHeight(height)
      if #available(iOS 13.0, *) {
        let menuInteraction = UIContextMenuInteraction(delegate: self)
        momentView.addInteraction(menuInteraction)
        momentView.isUserInteractionEnabled = true
      } 
    }
  }
  
  @available(iOS 13.0, *)
  fileprivate func createContextMenu() -> UIMenu {
    let deleteAction = UIAction(title: "Alles löschen", 
      image: UIImage(systemName: "trash")) { action in
        MainNC.singleton.deleteAll()
    }
    let deleteUserDataAction = UIAction(title: "Kundendaten löschen", 
      image: UIImage(systemName: "person.crop.circle.badge.minus")) { action in
        MainNC.singleton.deleteUserData()
    }
    let unlinkSubscriptionIdAction = UIAction(title: "Abo-Verknüpfung löschen", 
      image: UIImage(systemName: "person.crop.circle.badge.minus")) { action in
        MainNC.singleton.unlinkSubscriptionId()
    }
    let requestSubscriptionNotification = UIAction(title: "Abo-Push anfordern",
      image: UIImage(systemName: "dot.radiowaves.left.and.right")) { action in
        MainNC.singleton.testNotification(type: NotificationType.subscription)
    }
    let requestDownloadNotification = UIAction(title: "Download-Push anfordern",
      image: UIImage(systemName: "dot.radiowaves.left.and.right")) { action in
        MainNC.singleton.testNotification(type: NotificationType.subscription)
    }
    return UIMenu(title: "", children: [deleteAction, deleteUserDataAction,
      unlinkSubscriptionIdAction, requestSubscriptionNotification, requestDownloadNotification])
  }
  
  fileprivate var sectionPressedClosure: ((Int)->())?
  fileprivate var imagePressedClosure: (()->())?
  
  /// Define closure to call when a content label has been pressed
  public func onSectionPress(closure: @escaping (Int)->()) {
    sectionPressedClosure = closure
  }

  /// Define closure to call when the image has been tapped
  public func onImagePress(closure: @escaping ()->()) {
    imagePressedClosure = closure
  }
  
  /// Scroll bottom to row in tableview
  public func scrollBottomToIndex(index: Int, animated: Bool = false) {
    if let n = issue?.sections?.count, index <= n {
      let indexPath = IndexPath(row: index, section: 0)
      contentTableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
    }
  }
  
  /// Scroll top to row in tableview 
  public func scrollTopToIndex(index: Int, animated: Bool = false) {
    if let n = issue?.sections?.count, index <= n {
      let indexPath = IndexPath(row: index, section: 0)
      contentTableView.scrollToRow(at: indexPath, at: .top, animated: animated)
    }
  }
  
  /// Animate content tableview
  public func animateContent() {
    if let n = issue?.sections?.count {
      scrollBottomToIndex(index: n, animated: true)
      delay(seconds: 0.5) { self.scrollTopToIndex(index: 0, animated: true) }
    }
  }
  
  @objc fileprivate func imageTapped() {
    if let closure = imagePressedClosure { closure() }
  }
  
  // MARK: - Life Cycle
  
  override public func viewDidLoad() {
    super.viewDidLoad()
    resetColors()
    Defaults.receive { [weak self] nfn in
      if nfn.key == "colorMode" { 
        self?.resetColors() 
        self?.contentTableView.reloadData()
      }
    }
    let imageTap = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
    momentView.isUserInteractionEnabled = true
    momentView.addGestureRecognizer(imageTap)
    momentView.layer.shadowOpacity = 0.2
    momentView.layer.shadowOffset = CGSize(width: 5, height: 5)
    momentView.layer.shadowRadius = 1
    contentTableView.delegate = self
    contentTableView.dataSource = self
    contentTableView.backgroundColor = UIColor.clear
    contentTableView.separatorColor = UIColor.clear
    contentTableView.register(SectionCell.self, forCellReuseIdentifier: sectionCell)
    resetIssue()
    resetImage()
  }

  // number of table view animations so far
  fileprivate static var nAnimations = 0
  
  override public func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if ContentTableVC.showAnimations {
      if ContentTableVC.nAnimations < 2 {
        animateContent()
        ContentTableVC.nAnimations += 1
      }
    }
//    delay(seconds: 3) { 
//      Defaults.singleton["colorMode"] = "dark" 
//      delay(seconds: 3) {
//        Defaults.singleton["colorMode"] = "light"
//      }
//    }
  }
  
  override public func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
  }
  
  // MARK: - UIContextMenuInteractionDelegate protocol

  @available(iOS 13.0, *)
  public func contextMenuInteraction(_ interaction: UIContextMenuInteraction, 
    configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
    return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) 
    { _ -> UIMenu? in 
      return self.createContextMenu()
    }
  }

  // MARK: - UITableViewDataSource protocol
  
  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int)
    -> Int {
    if let n = issue?.sections?.count { return n + 1 }
    else { return 0 }
  }
  
  public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)
    -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: sectionCell, 
                                             for: indexPath) as! SectionCell
    guard let issue = issue, 
      let sections = issue.sections,
      let imprint = issue.imprint
    else { return cell }
    let n = indexPath.row
    if n >= sections.count { 
      cell.cellLabel.text = imprint.title ?? "Impressum"
      cell.cellLabel.textColor = ContentTableVC.ArticleColor
    }
    else {
      cell.cellLabel.text = sections[n].name
      cell.cellLabel.textColor = ContentTableVC.SectionColor      
    }
    return cell
  }
  
  // MARK: - UITableViewDelegate protocol
  
  public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return CGFloat(ContentTableVC.CellHeight)
  }
  
  public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if let closure = sectionPressedClosure { closure(indexPath.row) }
  }
    
} // ContentTableVC
