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
  var viewName: String { get }
}

extension HelpProviding {
  var newItemsCount: Int { helpItems.count - (lastIndex ?? 0)  }
  
  /// The concrete type name of the conforming object
  var typeName: String {
    String(describing: type(of: self))
  }
  func isSameType(as other: HelpProviding) -> Bool {
    self.typeName == other.typeName
  }
  
  var viewName: String {
    switch self {
      case is HomeVC:
        return "für Home"
      case is SectionVC:
        return "in der Ressortübersicht"
      case is ArticleVC:
        return "in der Artikelansicht"
      case is TazPdfPagesViewController:
        return "in der Zeitungsansicht"
      case is ArticlePlayer:
        return "für den Player"
      case is NewContentTableVC:
        return "für das Inhaltsverzeichnis"
      default:
        return "für diesen Bereich"
    }
  }
  
  var lastIndex: Int? {
    switch self {
      case is HomeVC:
        return HelpBusiness.shared.lastHomeHelpIndex
      case is SectionVC:
        return HelpBusiness.shared.lastSectionHelpIndex
      case is ArticleVC:
        return HelpBusiness.shared.lastArticleHelpIndex
      case is TazPdfPagesViewController:
        return HelpBusiness.shared.lastPdfHelpIndex
      case is ArticlePlayer:
        return HelpBusiness.shared.lastPlayerHelpIndex
      case is NewContentTableVC:
        return HelpBusiness.shared.lastSliderHelpIndex
      default:
        return nil
    }
  }
  
  var doNotShowHelpInThisAreaAnymore: Bool {
    get { lastIndex ?? 0  < 0 }
    set {
      guard newValue == true else { return }
      switch self {
        case is HomeVC:
          HelpBusiness.shared.lastHomeHelpIndex = -1
        case is SectionVC:
          return HelpBusiness.shared.lastSectionHelpIndex = -1
        case is ArticleVC:
          return HelpBusiness.shared.lastArticleHelpIndex = -1
        case is ArticlePlayer:
          return HelpBusiness.shared.lastPlayerHelpIndex = -1
        case is TazPdfPagesViewController:
          return HelpBusiness.shared.lastPdfHelpIndex  = -1
        case is NewContentTableVC:
          return HelpBusiness.shared.lastSliderHelpIndex = -1
        default:
          break
      }
    }
  }
  
  func showHelpButton(){
    guard doNotShowHelpInThisAreaAnymore == false else { return }
    (TazAppEnvironment.sharedInstance.rootViewController
            as? MainTabVC)?.helpButton.showAnimated()
  }
  
  func hideHelpButton(){
    (TazAppEnvironment.sharedInstance.rootViewController
            as? MainTabVC)?.helpButton.hideAnimated()
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
  @Default("lastPdfHelpIndex")
  public var lastPdfHelpIndex: Int
  @Default("helpUsedOnce")
  public var helpUsedOnce: Bool
  @Default("isInitialStartup")
  public var isInitialStartup: Bool
  
  func resetHelp(){
    helpUsedOnce = false
    isInitialStartup = true
    lastHomeHelpIndex = 0
    lastSectionHelpIndex = 0
    lastArticleHelpIndex = 0
    lastPlayerHelpIndex = 0
    lastSliderHelpIndex = 0
    lastPdfHelpIndex = 0
  }
  
  func disableCurrentHelp(){
    guard let mainTabVc = TazAppEnvironment.sharedInstance.rootViewController as? MainTabVC,
    var helpProvider = mainTabVc.currentHelpProvider else { return }
    helpProvider.doNotShowHelpInThisAreaAnymore = true
    Notification.send(Const.NotificationNames.helpProviderChanged)
  }
  
  func openHelp(){
    guard let window = UIApplication.shared.activeKeyWindow,
          let mainTabVc = TazAppEnvironment.sharedInstance.rootViewController as? MainTabVC,
    var helpProvider = mainTabVc.currentHelpProvider else { return }
    let helpItems = helpProvider.helpItems
    let helpItemsCount = helpItems.count
    
    if let cvc = helpProvider as? ContentVC {
      cvc.toolBar.show(show: true, animated: false)
    }
    
    ///show layer
    let helpView = HelpView()
    if helpProvider is ArticlePlayer {
      helpView.pageControllBottomOffset = -250
    }
    
//    switch helpProvider {
//      case is ArticlePlayer:
//        helpView.pageControllBottomOffset = -250
//      case is HomeVC:
//        break
//      default:
//        break //no defaults here
//    }
    
    (helpProvider as? HomeVC)?.isInitialStartup = false
    
    helpView.doNotShowHelpInThisAreaAnymoreLabel.text =
    "Hilfe \(helpProvider.viewName) nicht mehr anzeigen."
    
    let close = {
      Notification.send(Const.NotificationNames.helpProviderChanged)
      UIAccessibility.post(notification: .layoutChanged, argument: mainTabVc.view)
      UIView.animate(withDuration: 0.5,
                     delay: 0,
                     options: UIView.AnimationOptions.curveEaseInOut,
                     animations: {
        helpView.alpha = 0.0
      }, completion: {(_) in
        helpView.removeFromSuperview()
        helpView.accessibilityViewIsModal = false
      })
    }
    
    ///addSubview changes index, save it before
    let lastIndex = lastHelpItemIndex(for: helpProvider)
    helpView.onDisplay {[weak self] idx in
      self?.display(idx: idx, for: helpProvider)
      if idx + 1 >= helpItemsCount {
        helpView.doNotShowHelpInThisAreaAnymore.showAnimated()
        helpView.doNotShowHelpInThisAreaAnymore.onTapping { _ in
          helpProvider.doNotShowHelpInThisAreaAnymore = true
          close()
          Notification.send(Const.NotificationNames.helpProviderChanged)
        }
      } else {
        helpView.doNotShowHelpInThisAreaAnymore.isHidden = true
      }
    }
    
    helpView.items = helpItems
    helpView.frame = window.bounds
    helpView.alpha = 0.0
    window.addSubview(helpView)
    helpView.setLastMaxIndex(idx: lastIndex)
    UIView.animate(withDuration: 0.2,
                   delay: 0,
                   options: UIView.AnimationOptions.curveEaseIn,
                   animations: {
      helpView.alpha = 1.0
    }, completion: { (_) in
      if helpView.isTopmost == false {
        window.bringSubviewToFront(helpView)
      }
      helpView.accessibilityViewIsModal = true
      UIAccessibility.post(notification: .layoutChanged, argument: helpView)
    })
    helpView.onClose { close() }
  }
  
  private func lastHelpItemIndex(for helpProvider: HelpProviding) -> Int?{
    switch helpProvider {
      case is HomeVC:
        return lastHomeHelpIndex
      case is SectionVC:
        return lastSectionHelpIndex
      case is ContentVC:
        return lastArticleHelpIndex
      case is ArticlePlayer:
        return lastPlayerHelpIndex
      case is TazPdfPagesViewController:
        return lastPdfHelpIndex
      case is NewContentTableVC:
        return lastSliderHelpIndex
      default:
        return nil
    }
  }
  
  private func display(idx:Int, for helpProvider: HelpProviding){
    switch helpProvider {
      case is HomeVC:
        lastHomeHelpIndex = max(idx+1, lastHomeHelpIndex)
      case is SectionVC:
        lastSectionHelpIndex = max(idx+1, lastSectionHelpIndex)
      case is ArticleVC:
        lastArticleHelpIndex = max(idx+1, lastArticleHelpIndex)
      case is TazPdfPagesViewController:
        lastPdfHelpIndex = max(idx+1, lastPdfHelpIndex)
      case is ArticlePlayer:
        lastPlayerHelpIndex = max(idx+1, lastPlayerHelpIndex)
      case is NewContentTableVC:
        lastSliderHelpIndex = max(idx+1, lastSliderHelpIndex)
      default:
        break
    }
  }
  
  static let shared = HelpBusiness()
}

/// MARK: Access Helper
extension HelpBusiness {
  private static var mainTabVc: MainTabVC? {
    TazAppEnvironment.sharedInstance.rootViewController
     as? MainTabVC
  }
  
  static var helpButtonPlayerOffset: Double? {
    get { mainTabVc?.helpButtonPlayerOffset }
    set { if let newValue = newValue { mainTabVc?.helpButtonPlayerOffset = newValue } }
  }
  static var helpButtonToolbarOffset: Double? {
    get { mainTabVc?.helpButtonToolbarOffset }
    set { if let newValue = newValue { mainTabVc?.helpButtonToolbarOffset = newValue } }
  }
  static var helpButtonAdditionalSheetOffset: Double? {
    get { mainTabVc?.helpButtonAdditionalSheetOffset }
    set { if let newValue = newValue { mainTabVc?.helpButtonAdditionalSheetOffset = newValue } }
  }
  
  /// returns help button if currently visible for voiveover
  static var accessibileHelpButton: UIView? {
    get {
      guard let btn = mainTabVc?.helpButton else { return nil }
      if !btn.isHidden { return btn }
      return nil
    }
  }
}

extension MainTabVC {
  var currentHelpProvider: HelpProviding? {
    if ArticlePlayer.singleton.isMaxiPlayer {
      return ArticlePlayer.singleton
    }
    if let nav = selectedViewController as? UINavigationController {
      if let cvc = nav.visibleViewController as? ContentVC,
         cvc.slider?.isOpen == true {
        return cvc.slider?.slider as? HelpProviding
      }
      else if let cvc = nav.visibleViewController as? TazPdfPagesViewController,
         cvc.slider?.isOpen == true {
        return cvc.slider?.slider as? HelpProviding
      }
      return nav.visibleViewController as? HelpProviding
    } else {
      return selectedViewController as? HelpProviding
    }
  }
}
