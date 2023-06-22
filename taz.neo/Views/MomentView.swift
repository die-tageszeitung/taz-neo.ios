//
//  MomentView.swift
//
//  Created by Norbert Thies on 15.04.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// A MomentView displays an Image, an optional Spinner and an
/// optional Menue.
public class MomentView: UIView, Touchable {
  
  /// The ImageView
  public var imageView: UIImageView = UIImageView()
    
  // Aspect ratio constraint
  private var aspectRatioConstraint: NSLayoutConstraint? = nil
  
  // Spinner indicating activity
  private var spinner = UIActivityIndicatorView()
  
  /// Set the spinner spinning in case of activity
  public var isActivity: Bool {
    get { return spinner.isAnimating }
    set {
      if newValue {
        spinner.color
          = self.image?.description.contains("demo-moment-frame") ?? false
          ? .white
          : .gray
        spinner.startAnimating()
      }
      else { spinner.stopAnimating() }
    }
  }
  
  // Define the image to display
  public var image: UIImage? {
    get { return imageView.image }
    set(img) {
      imageView.image = img
      if let img = img {
        let s = img.size
        if let constraint = aspectRatioConstraint { constraint.isActive = false }
        aspectRatioConstraint = imageView.pinAspect(ratio: s.width/s.height)
      }
    }
  }
  
  public var tapRecognizer = TapRecognizer()
  
  private func setup() {
    addSubview(imageView)
    pin(imageView.left, to: self.left)
    pin(imageView.right, to: self.right)
    pin(imageView.centerY, to: self.centerY)
    spinner.hidesWhenStopped = true
    addSubview(spinner)
    pin(spinner.centerX, to: self.centerX)
    pin(spinner.centerY, to: self.centerY)
    self.bringSubviewToFront(spinner)
    self.backgroundColor = .clear
  }
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  /// The context menu
  public lazy var menu = ContextMenu(view: imageView)
  
} // MomentView

