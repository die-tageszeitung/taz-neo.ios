//
//  IssueTilesCvcCell.swift
//  taz.neo
//
//  Created by Ringo Müller on 14.02.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

class IssueTilesCvcCell : IssueCollectionViewCell {
  
  public let button = DownloadStatusButton()
  let buttonHeight:CGFloat = 30.0
  let buttonOffset:CGFloat = 0.0
  
  var shorter: Bool = false
  
  private var shortDate:String?
  private var shorterDate:String?
  
  public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if !Device.isIpad { return }
    updateTraitCollection(traitCollection)
  }

  override func didUpdateDate() {
    super.didUpdateDate()
    updateLabel()
    updateDownloadButton()
  }
  
  override func didUpdateIssue() {
    super.didUpdateIssue()
    updateLabel()
    updateDownloadButton()
  }
  
  func updateLabel(){
    guard let issue = issue else {
      button.label.text = date?.short ?? "-"
      return
    }
    button.label.text
    = issue.validityDateText(timeZone: GqlFeeder.tz,
                             short: true,
                             shorter: shorter,
                             leadingText: "")
  }
  
  func updateDownloadButton(){
    guard let issue = issue else {
      button.indicator.downloadState = .waiting
      return
    }
    
    momentView.isActivity = issue.isDownloading
    button.setStatus(from: issue)
  }
  
  func updateTraitCollection(_ traitCollection: UITraitCollection){
    shorter
    = Device.isIpad
    ? traitCollection.horizontalSizeClass == .compact
    : UIWindow.size.width <= 375 //Iphone 6-iPhone 13mini
    updateLabel()
  }
  
  public override func prepareForReuse() {
    super.prepareForReuse()
    self.button.label.text = nil
  }
  
  override func setup(){
    super.setup()
    contentView.layer.borderWidth = 0.0
    cvBottomConstraint?.isActive = false
    updateTraitCollection(traitCollection)
    
    ///**NO SUPER SETUP!**
    /**
     Bugfix after Merge
     set ImageViews BG Color to same color like Collection Views BG fix white layer on focus
     UIColor.clear or UIColor(white: 0, alpha: 0) did not work
     Issue is not in last Build before Merge 0.4.18-2021011501 ...but flickering is there on appearing so its half of the bug
     - was also build with same xcode version/ios sdk
     issue did not disappear if deployment target is set back to 11.4
     */
//    momentView.backgroundColor = .black
//    momentView.contentMode = .scaleAspectFit
//    menu = ContextMenu(view: momentView)
    
    pin(momentView.bottom,
        to: contentView.bottom,
        dist: -buttonHeight-buttonOffset,
        priority: .defaultHigh)
    
    contentView.addSubview(button)
    pin(button, to: contentView, exclude: .top)
    button.pinHeight(buttonHeight)
    pin(button.topGuide(), to: momentView.bottomGuide(), dist: buttonOffset, priority: .fittingSizeLevel)
    button.label.font = Const.Fonts.contentFont(size: 15.0)
    button.color = Const.Colors.appIconGrey
    
    Notification.receive("issueProgress", closure: {   [weak self] notif in
      guard let self = self else { return }
      if (notif.object as? Issue)?.date != self.issue?.date { return }
      if let (loaded,total) = notif.content as? (Int64,Int64) {
        let percent = Float(loaded)/Float(total)
        if percent > 0.05 {
          self.button.indicator.downloadState = .process
          self.button.indicator.percent = percent
        }
        if percent == 1.0 {  self.momentView.isActivity = false }
      }
    })
  }
  /*
   ****
   From CVC
   
   
   guard let issue = service.getIssue(at: indexPath.row) else {
     cell.button.indicator.downloadState = .waiting
    
     return cell
     
     
     if service.hasDownloadableContent(issue: issue) {
       cell.button.onTapping {[weak self] _ in
         guard let self else { return }
         cell.button.indicator.downloadState = .waiting
         cell.button.indicator.percent = 0.0
         cell.momentView.isActivity = true
         self.service.getCompleteIssue(issue: issue)
       }
       cell.button.indicator.downloadState = .notStarted
     }
     //
     //    if cell.interactions.isEmpty {
     //      let menuInteraction = UIContextMenuInteraction(delegate: self)
     //      cell.addInteraction(menuInteraction)
     //      cell.backgroundColor = .black
     //    }
    
   }
   
   ****
   
   
   


  
  private func update(){
    guard let issue = issue else { return }
    updateLabel()
    
   
  }
  */
}

