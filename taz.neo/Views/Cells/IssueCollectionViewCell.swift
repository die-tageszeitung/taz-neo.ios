//
//  IssueCollectionViewCell.swift
//  taz.neo
//
//  Created by Ringo Müller on 30.01.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

class IssueCollectionViewCell: UICollectionViewCell {
  
//  var requestImageRepeatCount = 0
//  let requestImageMaxRepeatCount = 5
//  let requestImageDelay = 5.0
 
  let momentView = MomentView()
  let emptyView = UIView()
  
  var cvBottomConstraint: NSLayoutConstraint?

  var data: IssueCellData? {
    didSet {
      update()
    }
  }
  
  func update(){
    let img = data?.image
    momentView.image = img
    
    momentView.isActivity = img == nil
    emptyView.isHidden = img != nil
  }
  
//  final var issue: StoredIssue? {
//    didSet {
//      if oldValue == issue { return }
//      didUpdateIssue()
//    }
//  }
//  var previousIncompleeteLoadIssueDate: Date?
  
//  final var publicationDate: PublicationDate?{ didSet { didUpdateDate()}}
//  var image: UIImage? {
//    didSet {
//      momentView.image = image
//      momentView.isActivity = image == nil
//
//      contentView.layer.borderColor
//      = image == nil ? UIColor.lightGray.cgColor : UIColor.clear.cgColor
//    }
//  }

//  func didUpdateDate(){
//    print("didUpdateDate new publicationDate: \(publicationDate) self: \(self.hash) 7XßC3")
//  }
//  func didUpdateIssue(){
//    requestImageRepeatCount = 0
////    setupRequestImageAgain()
//    print("didUpdateIssue for publicationDate: \(publicationDate) issue: \(issue?.date.issueKey) self: \(self.hash) 7XßC3")
//  }
  
//  func setupRequestImageAgain(){
//    if image != nil { return }
//    if requestImageRepeatCount >= requestImageMaxRepeatCount { return }
//    requestImageRepeatCount += 1
//    onMainAfter(Double(requestImageRepeatCount)*requestImageDelay) {[weak self] in
//      Notification.send(Const.NotificationNames.issueMomentRequired, content: self?.issue)
//    }
//  }
  
  public override func prepareForReuse() {
    data = nil
//    print("prepareForReuse old publicationDate: \(publicationDate) (issue update for:) self: \(self.hash)")
//    if image == nil {
//      previousIncompleeteLoadIssueDate = issue?.date
//    }
//    image = nil
//    issue = nil
//    publicationDate = nil
  }
  
  func setup(){
    contentView.addSubview(emptyView)
    contentView.addSubview(momentView)
    cvBottomConstraint = pin(momentView, to: contentView).bottom
    emptyView.layer.borderWidth = 1.0
    emptyView.layer.cornerRadius = 7.0
    emptyView.layer.borderColor = UIColor.lightGray.cgColor
    pin(emptyView, to: momentView)
    
    Notification.receive(Const.NotificationNames.issueUpdate) { [weak self] notification in
      guard let selfKey = self?.data?.date.date.issueKey,
            let nData = notification.content as? IssueCellData,
            nData.date.date.issueKey == selfKey else { return }
      self?.data = nData
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
}
