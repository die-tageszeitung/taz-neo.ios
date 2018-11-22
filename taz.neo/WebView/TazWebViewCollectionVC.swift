//
//  TazWebViewCollectionVC.swift
//  taz.neo
//
//  Created by Norbert Thies on 25.09.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit

class TazWebViewCollectionVC: WebViewCollectionVC {
  
  var tazButton: UIButton!
  fileprivate var tazButtonPressedClosure: (()->())?
  
  func onTazButton(closure: @escaping ()->()) {
    tazButtonPressedClosure = closure
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    let img = UIImage.init(named: "taz")
    tazButton = UIButton(type: .custom)
    tazButton.setImage(img, for: .normal)
    tazButton.alpha = 0.9
    self.view.addSubview(tazButton)
    tazButton.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      tazButton.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 11),
      tazButton.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor),
      tazButton.widthAnchor.constraint(equalToConstant: 75),
      tazButton.heightAnchor.constraint(equalTo: tazButton.widthAnchor, multiplier: 33.0/67.0),
      ])
    tazButton.addTarget(self, action: #selector(tazButtonPressed(sender:)), for: .touchUpInside)
  }
  
  @objc func tazButtonPressed(sender: UIButton) {
    debug()
    if let closure = tazButtonPressedClosure { closure() }
  }
  
}
