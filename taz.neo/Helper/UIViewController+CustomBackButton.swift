//
//  UIViewController+CustomBackButton.swift
//  taz.neo
//
//  Created by Ringo Müller-Gromes on 29.10.26.
//  Copyright © 2026 Ringo Müller-Gromes. All rights reserved.
//

import UIKit

extension UIViewController {
  
  func installCustomBackButton() {
    let button = UIButton(type: .system)
    button.setImage(
      UIImage(systemName: "chevron.left"),
      for: .normal
    )
    
    button.tintColor = .label
    button.backgroundColor = Const.SetColor.taz(.textFieldBackground).color
    
    button.layer.cornerRadius = 18
    button.clipsToBounds = true
    
    button.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      button.widthAnchor.constraint(equalToConstant: 36),
      button.heightAnchor.constraint(equalToConstant: 36)
    ])
    
    button.accessibilityLabel = "Zurück"
    button.addTarget(
      self,
      action: #selector(customBackButtonTapped),
      for: .touchUpInside
    )
    
    let item = UIBarButtonItem(customView: button)
    
//    if #available(iOS 26.0, *) {
//      item.hidesSharedBackground = true
//    }
    
    navigationItem.leftBarButtonItem = item
  }
  
  @objc private func customBackButtonTapped() {
    navigationController?.popViewController(animated: true)
  }
}
