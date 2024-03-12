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
