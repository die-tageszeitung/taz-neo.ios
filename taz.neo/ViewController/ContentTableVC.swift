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
  static let SectionColor = UIColor.rgb(0xd50d2e)
  static let ArticleColor = UIColor.darkGray
  static let DateColor = UIColor.darkGray
  static let TextFont = UIFont.boldSystemFont(ofSize: 18)
  static let DateTextFont = UIFont.systemFont(ofSize: 14)
  static let CellHeight = CGFloat(30)
  static let ImageWidth = CGFloat(150)
  
  // The TableView cell name
  fileprivate let sectionCell = "sectionCell"
  
  // The TableViewCell
  class SectionCell: UITableViewCell {
    
    lazy var cellView: UIView = {
      let view = UIView()
      view.backgroundColor = UIColor.white
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
      self.backgroundColor = UIColor.white
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
    return UIMenu(title: "", children: [deleteAction, deleteUserDataAction])
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
    view.backgroundColor = UIColor.white
    issueDateLabel.backgroundColor = UIColor.white
    issueDateLabel.textColor = ContentTableVC.DateColor
    issueDateLabel.font = ContentTableVC.DateTextFont
    let imageTap = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
    momentView.isUserInteractionEnabled = true
    momentView.addGestureRecognizer(imageTap)
    momentView.layer.shadowColor = UIColor.black.cgColor
    momentView.layer.shadowOpacity = 0.2
    momentView.layer.shadowOffset = CGSize(width: 5, height: 5)
    momentView.layer.shadowRadius = 1
    contentTableView.delegate = self
    contentTableView.dataSource = self
    contentTableView.backgroundColor = UIColor.white
    contentTableView.separatorColor = UIColor.white
    contentTableView.register(SectionCell.self, forCellReuseIdentifier: sectionCell)
    resetIssue()
    resetImage()
  }

  // number of table view animations so far
  fileprivate static var nAnimations = 0
  
  override public func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if ContentTableVC.nAnimations < 2 {
      animateContent()
      ContentTableVC.nAnimations += 1
    }
  }
  
  override public func viewDidDisappear(_ animated: Bool) {
    super.viewDidAppear(animated)
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
