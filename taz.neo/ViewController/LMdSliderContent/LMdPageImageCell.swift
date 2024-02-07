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
  
  var issueDir: Dir?
  
  var page: Page? {
    didSet {
      #warning("deprecated: remove soon, just needed for pre RC3 Installations")
      if page?.facsimile != nil
          && page?.facsimile?.image(dir: issueDir) == nil
          && page?.facsimile?.fileName.suffix(4) == "webp" {
        ///throw away the webp facsimiles (which are also not loaded) and create the jpg ones
        (page as? StoredPage)?.facsimile = nil
      }
      /// -end of deprecated
      pageImageView.image = page?.facsimile?.image(dir: issueDir)?.left
      pageLabel.text = "Seite \(page?.pagina ?? "")"
    }
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()///**IMPORTANT!!!!!!!!!!!**
    page=nil
  }
  
  func setup(){
    pageImageView.pinAspect(ratio: 0.69,
                            pinWidth: false,
                            priority: .defaultHigh)
    pageImageView.contentMode = .scaleAspectFit
    pageImageView.shadow()
    pageLabel.lmdBenton(size: 13.0).centerText()
    self.contentView.addSubview(pageImageView)
    self.contentView.addSubview(pageLabel)
    pin(pageImageView.left, to: self.contentView.left)
    pin(pageImageView.right, to: self.contentView.right)
    pin(pageImageView.top, to: self.contentView.top, dist: 8.0)
    pin(pageLabel, to: self.contentView, exclude: .top)
    pin(pageLabel.top, to: pageImageView.bottom, dist: 7.0)
    pageLabel.lmdBenton(size: 14.0)
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
