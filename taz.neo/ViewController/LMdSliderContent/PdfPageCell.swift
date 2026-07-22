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
class PdfPageCell: UICollectionViewCell, LMdSliderCell {
  
  var pagina: String? /// e.g. "1" (single), "2-3" (double), nil (ad)
  var listPrefix: String? /// e.g. "Seite" or nil for ads
  var pageRessort: String? ///e.g. "inland" or "anzeige" for ads
  
  static let reuseIdentifier = "PdfPageCellIdentifier"
  
  let pageImageView = UIImageView()
  let pageLabel = UILabel()
  
  func configure(pageMode: Bool) {
    if !pageMode {
      pageLabel.text = "\(listPrefix ?? "") \(pagina ?? "")"
      pageLabel.contentFont(size: 12.0)
      return
    }
    pageLabel.boldContentFont(size: 14.0)
    let attributedString = NSMutableAttributedString()
    if let pagina {
      let font
      = [NSAttributedString.Key.font:
          Const.Fonts.contentFont(size: Const.Size.SmallerFontSize)]
      attributedString.append(NSAttributedString(string: "\(pagina) ",
                                                 attributes: font))
    }
    if let pageRessort {
      let font
      = [NSAttributedString.Key.font:
          Const.Fonts.titleFont(size: Const.Size.SmallerFontSize)]
      attributedString.append(NSAttributedString(string: "\(pageRessort)",
                                                 attributes: font))
      pageLabel.attributedText = attributedString
    }
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    pageImageView.image = nil
    pageLabel.text = nil
  }
  
  func setup(){
    contentView.clipsToBounds = true
    pageImageView.pinAspect(ratio: Const.Size.LmdPageAspect,
                            pinWidth: false,
                            priority: .defaultHigh)
    pageImageView.contentMode = .scaleAspectFit
    pageImageView.shadow()
    pageLabel.textAlignment = .left
    pageLabel.contentFont(size: Const.Size.SmallerFontSize)
    self.contentView.addSubview(pageImageView)
    self.contentView.addSubview(pageLabel)
    pin(pageImageView, to: self.contentView, exclude: .bottom)
    pin(pageLabel.left, to: self.contentView.left)
    pin(pageLabel.right, to: self.contentView.right)
    pin(pageLabel.top, to: pageImageView.bottom, dist: 3.0)
    ///Cell height is defined in PdfMenuListFlowLayout ...evaluateLayout...cellHeight
    ///do not pin bottom
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
