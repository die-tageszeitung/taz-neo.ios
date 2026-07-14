//
//  LMdPageImageCell.swift
//  taz.neo
//
//  Created by Ringo Müller on 11.01.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import UIKit
import NorthUIKit

/// helper to only display left side of an image, used within panorama pages in lmd slider to display only left side
fileprivate extension UIImage {
  var left: UIImage {
    if self.size.width < self.size.height { return self }
    guard let cgImage = self.cgImage else { return self }
    guard let imageRef
    = cgImage.cropping(to: CGRect(x: 0,
                                  y: 0,
                                  width: self.size.width/2,
                                  height: self.size.height))
    else { return self }
    return UIImage(cgImage: imageRef)
  }
}


/// page cell displaying page image and page number
class LMdPageImageCell: UICollectionViewCell, LMdSliderCell {
  let pageImageView = UIImageView()
  let pageLabel = UILabel()
  
  override func prepareForReuse() {
    super.prepareForReuse()///**IMPORTANT!!!!!!!!!!!**
    pageImageView.image = nil
    pageLabel.text = nil
  }
  
  func setup(){
    pageImageView.pinAspect(ratio: Const.Size.LmdPageAspect,
                            pinWidth: false,
                            priority: .defaultHigh)
    pageImageView.contentMode = .scaleAspectFit
    pageImageView.shadow()
    pageLabel.textAlignment = .left
    pageLabel.contentFont(size: Const.Size.SmallerFontSize)
    self.contentView.addSubview(pageImageView)
    self.contentView.addSubview(pageLabel)
    pin(pageImageView.left, to: self.contentView.left)
    pin(pageImageView.right, to: self.contentView.right)
    pin(pageImageView.top, to: self.contentView.top, dist: 0.0)
    pin(pageLabel, to: self.contentView, exclude: .top)
    pin(pageLabel.bottom, to: self.contentView.bottom, dist: 3.0)
    ///Cell height is defined in PdfMenuListFlowLayout ...evaluateLayout...cellHeight
    if let sv = self.contentView.superview {
      pin(self.contentView, to: sv)
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
