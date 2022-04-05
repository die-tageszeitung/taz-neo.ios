//
//  FeedbackHelper.swift
//  taz.neo
//
//  Created by Ringo Müller-Gromes on 02.10.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

extension UIView{
  static func seperator(color:UIColor? = nil, thickness:CGFloat = 0.5) -> UIView{
    let v = UIView()
    
    if let c = color {
      v.backgroundColor = c
    } else {
      v.backgroundColor = .lightGray
    }
    
    v.pinSize(CGSize(width: thickness, height: thickness), priority: .fittingSizeLevel)
    return v
  }
}

extension UIImageView {
  func addAspectRatioConstraint(image: UIImage?) {
    if let image = image {
      removeAspectRatioConstraint()
      let aspectRatio = image.size.width / image.size.height
      let constraint = NSLayoutConstraint(item: self, attribute: .width,
                                          relatedBy: .equal,
                                          toItem: self, attribute: .height,
                                          multiplier: aspectRatio, constant: 0.0)
      constraint.priority = .defaultHigh
      addConstraint(constraint)
    }
  }
  
  func removeAspectRatioConstraint() {
    for constraint in self.constraints {
      if (constraint.firstItem as? UIImageView) == self,
        (constraint.secondItem as? UIImageView) == self {
        removeConstraint(constraint)
      }
    }
  }
}

public class XImageView: UIImageView {
  override public var image: UIImage?{
    didSet{
      addAspectRatioConstraint(image: image)
    }
  }
}

extension UIImage{
  //shrink given image if target size is bigger than current return org image
  func resized(targetSize: CGSize, scale: CGFloat = 1.0) -> UIImage {
    let size = self.size
    
    if targetSize.width > size.width &&  targetSize.height > size.height{
      return self
    }
    
    let widthRatio  = targetSize.width  / size.width
    let heightRatio = targetSize.height / size.height
    
    // Figure out what our orientation is, and use that to form the rectangle
    var newSize: CGSize
    if(widthRatio > heightRatio) {
      newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
    } else {
      newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
    }
    
    // This is the rect that we've calculated out and this is what is actually used below
    let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
    
    // Actually do the resizing to the rect using the ImageContext stuff
    UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
    self.draw(in: rect)
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return newImage!
  }
}
