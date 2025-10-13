//
//  HelpBusiness.swift
//  taz.neo
//
//  Created by Ringo Müller on 13.10.25.
//  Copyright © 2025 taz. All rights reserved.
//

import NorthLib
import UIKit

protocol HelpProviding {
  /// called when the global help button is tapped
  var helpItems: [HelpItem] { get }
  var newItemsCount: Int { get }
}

extension HelpProviding {
  var newItemsCount: Int { helpItems.count - 1  }
  //  var newItemsCount: Int { helpItems.count - 1 - lastHelpItemIndex }
  
  /// The concrete type name of the conforming object
  var typeName: String {
    String(describing: type(of: self))
  }
  func isSameType(as other: HelpProviding) -> Bool {
    self.typeName == other.typeName
  }
}

class HelpBusiness {
  
  
  @Default("showHelp")
  public var showHelp: Bool
  
  @Default("lastHomeHelpIndex")
  public var lastHomeHelpIndex: Int
  @Default("lastSectionHelpIndex")
  public var lastSectionHelpIndex: Int
  @Default("lastArticleHelpIndex")
  public var lastArticleHelpIndex: Int
  @Default("lastPlayerHelpIndex")
  public var lastPlayerHelpIndex: Int
  @Default("lastSliderHelpIndex")
  public var lastSliderHelpIndex: Int
  
  
  func openHelp(){
    guard let window = UIApplication.shared.delegate?.window,
          let mainTabVc = TazAppEnvironment.sharedInstance.rootViewController as? MainTabVC,
    let helpProvider = mainTabVc.currentVisibleHelpController()else { return }
    
    ///show layer
    let helpView = HelpView()
    if helpProvider is ArticlePlayer {
      helpView.pageControllBottomOffset = -250
    }
    
    helpView.onDisplay { idx in
      //      helpProvider.onDisplay(idx: idx, isClosing: false)
    }
    helpView.items = helpProvider.helpItems
    //    helpView.setLastMaxIndex(idx: lastHelpItemIndex)//NOT WORKING
    helpView.frame = window?.bounds ?? .zero // oder mit Auto Layout Constraints
    
    helpView.alpha = 0.0
    window?.addSubview(helpView)
    
    UIView.animate(withDuration: 0.7,
                   delay: 0,
                   options: UIView.AnimationOptions.curveEaseInOut,
                   animations: {
      helpView.alpha = 1.0
    }, completion: { (_) in
      if helpView.isTopmost == false {
        window?.bringSubviewToFront(helpView)
      }
    })
    helpView.onClose {
      UIView.animate(withDuration: 0.7,
                     delay: 0,
                     options: UIView.AnimationOptions.curveEaseInOut,
                     animations: {
        helpView.alpha = 0.0
      }, completion: {(_) in
        helpView.removeFromSuperview()
      })
    }
  }
  
  static let shared = HelpBusiness()
}


fileprivate extension MainTabVC {
  func currentVisibleHelpController() -> HelpProviding? {
    if ArticlePlayer.singleton.isMaxiPlayer {
      return ArticlePlayer.singleton
    }
    if let nav = selectedViewController as? UINavigationController {
      if let cvc = nav.visibleViewController as? ContentVC,
         cvc.slider?.isOpen == true,
         let menu = cvc.slider?.slider as? HelpProviding {
          return menu
      }
      return nav.visibleViewController as? HelpProviding
    } else {
      return selectedViewController as? HelpProviding
    }
  }
}
