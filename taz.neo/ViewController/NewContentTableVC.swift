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
  
  var feeder:Feeder?
  var image:UIImage?
  var issue:Issue?
  var largestTextWidth = 0.0
  var expandedSections: [Int] = []
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
  
  
}


class NewContentTableVcHeader: UIView {
  
}
