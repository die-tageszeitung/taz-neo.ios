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
  
  public var toolBar = OverviewContentToolbar()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.addMenuItem(title: "PDF Ansicht beenden", icon: "eye.slash") { [weak self] title in
      self?.dismiss(animated: true)
    }
    self.iosHigher13?.addMenuItem(title: "Abbrechen", icon: "multiply.circle") { (_) in }
    
    setupToolbar()
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
  
  
  func setupToolbar() {
    //the button tap closures
    let onHome:((ButtonControl)->()) = {   [weak self] _ in
      self?.dismiss(animated: true)
    }
    
    let onPDF:((ButtonControl)->()) = {   [weak self] control in
      self?.dismiss(animated: true)
    }
    
    //the buttons and alignments
    _ = toolBar.addImageButton(name: "Home",
                           onPress: onHome,
                           direction: .left,
                           symbol: "house", //the prettier symbol ;-)
                           accessibilityLabel: "Übersicht"
//                           vInset: 0.2,hInset: 0.2 //needed if old symbol used
                           )
    toolBar.addSpacer(.left)
    _ = toolBar.addImageButton(name: "PDF",
                           onPress: onPDF,
                           direction: .right,
                           symbol: "iphone.homebutton",
                           accessibilityLabel: "Zeitungsansicht",
                           hInset: 0.15
    )
    
    //the toolbar setup itself
    toolBar.setButtonColor(Const.Colors.darkTintColor)
    toolBar.backgroundColor = Const.Colors.darkToolbar
    toolBar.pinTo(self.view)
    
//    if let thumbCtrl = self.thumbnailController {
//      thumbCtrl.whenScrolled(minRatio: 0.01){ [weak self] ratio in
//        if ratio < 0 { self?.toolBar.hide()}
//        else { self?.toolBar.hide(false)}
//      }
//    }
    
//    if let pageController = self.pageController {
//      pageController.collectionView?.delegate = self
//    }
  }
}

//extension TazPdfViewController : UICollectionViewDelegate {
//  
//}


