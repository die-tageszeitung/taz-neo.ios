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
  
  var cvBottomConstraint: NSLayoutConstraint?

  final var issue: StoredIssue? { didSet { didUpdateIssue()}}
  final var date: Date?{ didSet { didUpdateDate()}}
  var image: UIImage? {
    didSet {
      momentView.image = image
      momentView.isActivity = image == nil
      
      contentView.layer.borderColor
      = image == nil ? UIColor.lightGray.cgColor : UIColor.clear.cgColor
    }
  }

  func didUpdateDate(){}
  func didUpdateIssue(){}
  
  public override func prepareForReuse() {
    image = nil
    issue = nil
    date = nil
  }
  
  func setup(){
    contentView.addSubview(momentView)
    cvBottomConstraint = pin(momentView, to: contentView).bottom
    contentView.layer.borderWidth = 1.0
    contentView.layer.cornerRadius = 7.0
    
    Notification.receive(Const.NotificationNames.issueUpdate) { [weak self] notification in
      guard let date = notification.content as? Date,
            let service = notification.sender as? IssueOverviewService,
            date.short == self?.date?.short else { return }
      //set issue if not available yet
      if self?.issue == nil { self?.issue = service.issue(at: date) }
      //skip for now if issue still loading
      guard let issue = self?.issue else { return }
      //set image if not available yet
      if self?.momentView.image == nil {
        let img = service.image(for: issue)
        if img == nil { return }
        onMain {[weak self] in
          guard date.short == self?.date?.short else { return }
          self?.image = img
        }
      }
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
