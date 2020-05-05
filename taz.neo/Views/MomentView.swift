//
//  MomentView.swift
//
//  Created by Norbert Thies on 15.04.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// A MomentView displays an Image, an optional Spinner and an
/// optinal Menue.
public class MomentView: UIView, UIContextMenuInteractionDelegate, Touchable {
  
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
      if newValue { spinner.startAnimating() } 
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
    if #available(iOS 13, *) { 
      spinner.style = .large 
      spinner.color = .black
    }
    else { spinner.style = .whiteLarge }
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
  
  /// Define the menu to display on long touch (iOS >= 13)
  public var menu: [(title: String, icon: String, closure: (String)->())] = [] {
    willSet {
      if menu.count == 0 {
        imageView.isUserInteractionEnabled = true   
        if #available(iOS 13.0, *) {
          let menuInteraction = UIContextMenuInteraction(delegate: self)
          imageView.addInteraction(menuInteraction)      
        }
        else {
          let longTouch = UILongPressGestureRecognizer(target: self, 
                            action: #selector(actionMenuTapped))
          longTouch.numberOfTouchesRequired = 1
          imageView.addGestureRecognizer(longTouch)
        }
      }      
    }
  }

  @objc func actionMenuTapped(_ sender: UIGestureRecognizer) {
    var actionMenu: [UIAlertAction] = []
    for m in menu {
      actionMenu += Alert.action(m.title, closure: m.closure)
    }
    Alert.actionSheet(actions: actionMenu)
  }
  
  /// Add an additional menu item
  public func addMenuItem(title: String, icon: String, 
                          closure: @escaping (String)->()) {
    menu += (title: title, icon: icon, closure: closure)
  }
  
  @available(iOS 13.0, *)
  fileprivate func createContextMenu() -> UIMenu {
    let menuItems = menu.map { m in
      UIAction(title: m.title, image: UIImage(systemName: m.icon)) {_ in m.closure(m.title) }
    }
    return UIMenu(title: "", children: menuItems)
  }
  
  // MARK: - UIContextMenuInteractionDelegate protocol

  @available(iOS 13.0, *)
  public func contextMenuInteraction(_ interaction: UIContextMenuInteraction, 
    configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
    return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) 
    { _ -> UIMenu? in 
      return self.createContextMenu()
    }
  }

} // MomentView

