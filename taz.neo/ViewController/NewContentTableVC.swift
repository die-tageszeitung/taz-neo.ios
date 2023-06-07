//
//  NewContentTableVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 06.06.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit


/// content table for app view of an issue displayed as flyout ("Flügel")
/// tableHedaer = moment + date
/// section Header = section title + chevron > or ^
/// cell as Article Preview (like in serach or bookmarks
public class NewContentTableVC: UITableViewController {
  
  fileprivate static let CellIdentifier = "NewContentTableVcCell"
  
  var feeder:Feeder?
  var image:UIImage?
  var issue:Issue?
  var largestTextWidth = 100.0
  var expandedSections: [Int] = []
  
  var widthConstraint:NSLayoutConstraint?
  
  fileprivate var sectionPressedClosure: ((Int)->())?
  fileprivate var imagePressedClosure: (()->())?
  
  
}
  
///lifecycle
extension NewContentTableVC {
  public override func viewDidLoad() {
    super.viewDidLoad()
    self.tableView.register(NewContentTableVcCell.self,
                            forCellReuseIdentifier: Self.CellIdentifier)
  }
  
  open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    self.widthConstraint?.constant = size.width
    
//    updateWidth(size.width)
  }
  
  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
//    widthConstraint = self.tableView.pinWidth(self.view.frame.size.width)
//    updateWidth(self.view.frame.size.width)
  }

//  func updateWidth(_ width:CGFloat) {
//    widthConstraint?.constant
//    topGradient.isHidden = UIDevice.current.orientation.isLandscape && Device.isIphone
//  }
}

///actions
extension NewContentTableVC {
  /// Define closure to call when a content label has been pressed
  public func onSectionPress(closure: @escaping (Int)->()) {
    sectionPressedClosure = closure
  }
  
  /// Define closure to call when the image has been tapped
  public func onImagePress(closure: @escaping ()->()) {
    imagePressedClosure = closure
  }
}

///handle expanded/collapsed
extension NewContentTableVC {
  func collapse(section: Int){
    
  }
  
  func expand(section: Int){
    
  }
  
  func toggle(section: Int){
    var animation = UITableView.RowAnimation.top
    if let idx = expandedSections.firstIndex(of: section) {
      expandedSections.remove(at: idx)
      animation = .bottom
    }
    else {
      expandedSections.append(section)
    }
    tableView.reloadSections([section], with: animation)
  }
  
  func collapseAll(){
    expandedSections = []
    tableView.reloadSections(IndexSet(allSectionIndicies),
                             with: .top)
  }
  
  func expandAll(){
    expandedSections = allSectionIndicies
    tableView.reloadSections(IndexSet(expandedSections),
                             with: .bottom)
  }
  
  var allSectionIndicies: [Int] { return Array(0...(issue?.sections?.count ?? 0))}
}

extension NewContentTableVC {
  public override func numberOfSections(in tableView: UITableView) -> Int {
    return issue?.sections?.count ?? 0
  }
  
  public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return issue?.sections?.valueAt(section)?.articles?.count ?? 0
  }
  
  public override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 32.0
  }
  
  public override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 22.0
  }
  
  public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let art = issue?.sections?.valueAt(indexPath.section)?.articles?.valueAt(indexPath.row) else {
      log("Article you tapped not found for section: \(indexPath.section), row: \(indexPath.row)")
      return
    }
    log("you tapped: \(art.title)")
  }
  
  public override func tableView(_ tableView: UITableView,
                                 cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell
    = tableView.dequeueReusableCell(withIdentifier: Self.CellIdentifier,
                                    for: indexPath) as? NewContentTableVcCell
    ?? NewContentTableVcCell()
    return cell
  }
  
  
}


fileprivate class NewContentTableVcHeader: UIView {
  
}

fileprivate  class NewContentTableVcCell: UITableViewCell {
  
}
