//
//  TazPdfViewController.swift
//  taz.neo
//
//  Created by Ringo Müller-Gromes on 18.11.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

class TazPdfViewController : PdfViewController{
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.addMenuItem(title: "PDF Ansicht beenden", icon: "eye.slash") { [weak self] title in
      self?.dismiss(animated: true)
    }
    self.iosHigher13?.addMenuItem(title: "Abbrechen", icon: "multiply.circle") { (_) in }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if let pageController = self.pageController {
      pageController.pageControl?.layer.shadowColor = UIColor.lightGray.cgColor
      pageController.pageControl?.layer.shadowRadius = 3.0
      pageController.pageControl?.layer.shadowOffset = CGSize(width: 0, height: 0)
      pageController.pageControl?.layer.shadowOpacity = 1.0
      pageController.pageControl?.pageIndicatorTintColor = UIColor.white
      pageController.pageControl?.currentPageIndicatorTintColor = Const.SetColor.CIColor.color
      pageController.menuItems = self.menuItems
    }
    
    if let thumbCtrl = self.thumbnailController {
      thumbCtrl.menuItems = self.menuItems
      thumbCtrl.cellLabelFont = Const.Fonts.contentFont(size: 8)
    }
  }
  
  /// Define the menu to display on long touch of a MomentView
  public var menuItems: [(title: String, icon: String, closure: (String)->())] = []

  /// Add an additional menu item
  public func addMenuItem(title: String, icon: String, closure: @escaping (String)->()) {
    menuItems += (title: title, icon: icon, closure: closure)
  }
}



