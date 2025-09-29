//
//  CoachmarksBusiness.swift
//  taz.neo
//
//  Created by Ringo Müller on 14.12.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

public class CoachmarkItem {
  var title: String
  var text: String
  var isCircleCutout: Bool
  var targetView: UIView
  
  init(title: String, text: String, isCircleCutout: Bool, targetView: UIView) {
    self.title = title
    self.text = text
    self.isCircleCutout = isCircleCutout
    self.targetView = targetView
  }
}

/*

extension Coachmarks.IssueCarousel {
  var title: String {
    switch self {
      case .pdfButton:
        return "Wie sieht’s denn hier aus?"
      case .loading:
        return "Ladestatus"
      case .tiles:
        return "All you can read"
    }
  }
  
  var text: String {
    switch self {
      case .pdfButton:
        return "Wie Sie lesen, ist ihr Bier – umschalten aufs gewohnte Zeitungslayout geht hier!"
      case .loading:
        return "Dieses Symbol zeigt an, dass die Ausgabe noch nicht heruntergeladen ist."
      case .tiles:
        return "Für die Übersicht aller Ausgaben auf einen Blick: Einfach nach oben scrollen."
    }
  }
}

extension Coachmarks.Section {
  var title: String {
    switch self {
      case .slider:
        return "Alles auf einen Klick"
      case .swipe:
        return "Unbestimmte Artikel"
    }
  }
  
  var text: String {
    switch self {
      case .slider:
        return "Für den vollen Durchblick einfach das Logo antippen – hier findet sich die vollständige Inhaltsangabe der Ausgabe."
      case .swipe:
        return "Ressorts und Artikel einfach genüsslich durchstöbern, indem man nach links und rechts wischt."
    }
  }
}

extension Coachmarks.Article {
  var title: String {
    switch self {
      case .audio:
        return "Lesen und lesen lassen."
      case .share:
        return "Teile und herrsche"
      case .font:
        return "Die taz ist unlesbar?"
    }
  }
  
  var text: String {
    switch self {
      case .audio:
        return "Wer hören will, muss klicken: Hinter diesem Symbol verbirgt sich unsere tolle Vorlesefunktion – einfach mal ausprobieren!"
      case .share:
        return "Der Artikel ist besonders gut? Oder nervt zu Tode? Mit der Share-Funktion kann man Freud wie Leid ganz einfach mit anderen teilen."
      case .font:
        return "Da schafft die individuelle Anpassung der Schriftgröße Abhilfe."
    }
  }
}

extension Coachmarks.Search {
  var title: String {
    switch self {
      case .filter:
        return "Die ganz persönliche Filterblase"
    }
  }
  
  var text: String {
    switch self {
      case .filter:
        return "Mit der Filter-Funktion neben dem Suchfeld wirklich nur das finden, was man auch sucht."
    }
  }
}
*/


public protocol CoachmarkVC where Self: UIViewController {
  var viewName: String { get }
  func targetView(for item: CoachmarkItem) -> UIView?
  
  /// Alternative Target: an image and optional a List of Locations where the Target should be placed
  /// - Parameter item: CoachmarkItem to get target for
  /// - Returns: Icon and a List ob target points if applicable
  /// if no ist of target points given, the image will be places under the Coachmark text
  func target(for item: CoachmarkItem) -> (UIImage, [UIView], [CGPoint])?
}

public class CoachmarksBusiness: DoesLog{
  
  @Default("showHelp")
  var showHelp: Bool
  
  @Default("cmLastPrio")
  var cmLastPrio: Int
  
  @Default("cmSessionCount")
  var cmSessionCount: Int
  
  /// Are we in facsimile mode
  @Default("isFacsimile")
  public var isFacsimile: Bool
  
  var count:Int = 0
  
  func reset(){
    count = 0
  }
  
  func showHelp(sender: CoachmarkVC){
    guard let helpSender = sender as? HelpPresentable else { return }
    guard let itm = helpSender.items.first else { return }
    showCoachmark(sender: sender, target: itm.targetView, item: itm)
    #warning("Alternative Target??? see below")
//    guard let item
//            = sender.items.filter({ item in
//              activeCmKeys.contains(where: {item.key ==  $0.key })
//    }).first else { return }
//
//    if let target = sender.targetView(for: item) {
//      (sender as? ContentVC)?.toolBar.show(show: true, animated: true)
//      showCoachmark(sender: sender, target: target, item: item)
//    }
//    else if let alternativeTarget = sender.target(for: item) {
//      showCoachmark(sender: sender, target: nil, item: item, alternativeTarget: alternativeTarget)
//    }
//    else {
//      log("Not show coachmarks for: \(item.key)")
//    }
    
//    extension CoachmarkVC {
//      public func target(for item: CoachmarkItem) -> (UIImage, [UIView], [CGPoint])? {
//        return nil
//      }
//    }
    
  }
  
  var currentActiveCMVC: CoachmarkVC?
  var currentCoachmarkView: CoachmarkView?
  
  func showCoachmark(sender: CoachmarkVC, target: UIView?, item: CoachmarkItem, alternativeTarget: (UIImage, [UIView], [CGPoint])? = nil) {
    guard let window = UIApplication.shared.delegate?.window else { return }
    //not show coachmark for hidden or not displayed elements
    if let target = target,
       let window = UIWindow.keyWindow,
       target.isHidden == true
        || target.isDescendant(of: window) == false
        || (target as? ButtonView)?.isHiddenInToolbar == true { return }
    guard target?.isVisible ?? true else { return } //if no targets
    guard currentActiveCMVC == nil else { return }
    currentActiveCMVC = sender
    
    ///show layer
    onMain {[weak self] in
      if self?.currentActiveCMVC?.isVisible == false {
        self?.currentActiveCMVC = nil
        return
     }
      
      let cv = CoachmarkView(target: target, item: item, alternativeTarget: alternativeTarget)
      cv.alpha = 0.0
      window?.addSubview(cv)
      self?.currentCoachmarkView = cv
      
      UIView.animate(withDuration: 0.7,
                     delay: 0,
                     options: UIView.AnimationOptions.curveEaseInOut,
                     animations: {
        cv.alpha = 1.0
                     }, completion: { [weak self] (_) in
                      if cv.isTopmost == false {
                        window?.bringSubviewToFront(cv)
                      }
                       if self?.currentActiveCMVC?.isVisible == false {
                        cv.targetView = nil
                        cv.removeFromSuperview()
                        self?.currentActiveCMVC = nil
                      }
                     })
      cv.onClose {[weak self]  in
        UIView.animate(withDuration: 0.7,
                       delay: 0,
                       options: UIView.AnimationOptions.curveEaseInOut,
                       animations: {
                        cv.alpha = 0.0
                       }, completion: {(_) in
                         cv.targetView = nil
                         cv.removeFromSuperview()
                
                        })
        self?.currentActiveCMVC = nil
        self?.currentCoachmarkView = nil
      }
    }
  }
  
  static let shared = CoachmarksBusiness()
}
