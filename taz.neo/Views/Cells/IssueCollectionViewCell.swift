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
 
  static let Identifier = "issueCollectionViewCell"
  
  let momentView = MomentView()
  let lbl = UILabel()

  public var image: UIImage? {
    didSet {
      momentView.image = image
    }
  }
  
  public override func prepareForReuse() {
    self.momentView.image = nil
  }
  
  override func willMove(toSuperview newSuperview: UIView?) {
    super.willMove(toSuperview: newSuperview)
    initializeIfNeeded()
  }
  
  func initializeIfNeeded(){
    if momentView.superview != nil { return }
    contentView.addBorder(.green)
    contentView.addSubview(momentView)
//    pin(momentView, to: contentView)
    momentView.pinSize(CGSize(width: 220, height: 330))
    momentView.centerX()
    momentView.centerY()
    contentView.addSubview(lbl)
    lbl.pinSize(CGSize(width: 120, height: 30))
    lbl.centerX()
    lbl.centerY()
    lbl.contentFont()
    lbl.textColor = .blue
    contentView.clipsToBounds = true
  }
}
