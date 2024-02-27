//
//  CoachmarksBusiness.swift
//  taz.neo
//
//  Created by Ringo Müller on 14.12.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/***
 
 Idea:
 
 UIViewcontroller
 
 
 
 */

public protocol CoachmarkItem: NameDescribable, CodingKey {
  var title: String { get }
  var text: String { get }
}

extension CoachmarkItem {
  var screenName: String { self.typeName }
  var itemName: String { self.stringValue }
  var key: String { screenName + "." + itemName }
  
  var isCircleCutout: Bool {
    switch key {
      case Coachmarks.Section.slider.key:
        return false
      default:
        return true
    }
  }
  
  var prio: Int {
    switch key {
      case Coachmarks.IssueCarousel.pdfButton.key,
        Coachmarks.Section.slider.key,
        Coachmarks.Article.audio.key:
        return 1
      case Coachmarks.Section.swipe.key,
        Coachmarks.Article.font.key:
        return 2
      case Coachmarks.IssueCarousel.loading.key:
        return 3
      case Coachmarks.Article.share.key,
        Coachmarks.IssueCarousel.tiles.key,
        Coachmarks.Search.filter.key:
        return 4
      default:
        return 4
    }
  }
}

fileprivate extension String {
  var coachmarkItem: (CoachmarkItem)? {
    for item in Coachmarks.all {
      if item.key == self { return item }
    }
    return nil
  }
}


struct Coachmarks {
  enum IssueCarousel: CoachmarkItem, CaseIterable { case pdfButton, loading, tiles}///HomeTVC
  enum Section: CoachmarkItem, CaseIterable { case slider, swipe }///SectionVC
  enum Article: CoachmarkItem, CaseIterable { case audio, share, font}///ArticleVC
  enum Search: CoachmarkItem, CaseIterable { case filter }
  
  static let all : [CoachmarkItem] = [
    Coachmarks.IssueCarousel.pdfButton,
    Coachmarks.Section.slider,
    Coachmarks.Article.audio,
    Coachmarks.Section.swipe,
    Coachmarks.Article.font,
    Coachmarks.IssueCarousel.loading,//no need to deactivate if used cm should be shown
    Coachmarks.Article.share,
    Coachmarks.IssueCarousel.tiles,
    Coachmarks.Search.filter
  ]
} // Coachmarks

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


public protocol CoachmarkVC where Self: UIViewController {
  var viewName: String { get }
  var preventCoachmark: Bool { get }
  func targetView(for item: CoachmarkItem) -> UIView?
  
  /// Alternative Target: an image and optional a List of Locations where the Target should be placed
  /// - Parameter item: CoachmarkItem to get target for
  /// - Returns: Icon and a List ob target points if applicable
  /// if no ist of target points given, the image will be places under the Coachmark text
  func target(for item: CoachmarkItem) -> (UIImage, [UIView], [CGPoint])?
}

extension CoachmarkVC {
  public var preventCoachmark: Bool { return false }
  
  var items: [CoachmarkItem] {
    switch viewName {
      case Coachmarks.IssueCarousel.typeName: return Coachmarks.IssueCarousel.allCases
      case Coachmarks.Section.typeName: return Coachmarks.Section.allCases
      case Coachmarks.Article.typeName: return Coachmarks.Article.allCases
      case Coachmarks.Search.typeName: return Coachmarks.Search.allCases
      default: return []
    }
  }
  
  public func showCoachmarkIfNeeded() {
    guard TazAppEnvironment.hasValidAuth,
          CoachmarksBusiness.shared.showCoachmarks,
          CoachmarksBusiness.shared.count < 3 else { return }
    CoachmarksBusiness.shared.showCoachmarkIfNeeded(sender: self)
  }
  
  func deactivateCoachmark(_ item: CoachmarkItem){
    CoachmarksBusiness.shared.deactivateCoachmark(item)
  }
  
  public func target(for item: CoachmarkItem) -> (UIImage, [UIView], [CGPoint])? {
    return nil
  }
}

///Helper to save Array<String> to kvstore
extension [CoachmarkItem]: StringConvertible {
  public static func fromString(_ str: String?) -> [CoachmarkItem] {
    return str?.split(separator: "»").compactMap{String($0).coachmarkItem } ?? []
  }
  public static func toString(_ val: Self) -> String {
    return val.map{ $0.key }.joined(separator: "»")
  }
}

public class CoachmarksBusiness: DoesLog{
  
  @Default("showCoachmarks")
  var showCoachmarks: Bool
  
  @Default("cmLastPrio")
  var cmLastPrio: Int
  
  @Default("cmSessionCount")
  var cmSessionCount: Int
  
  /// Are we in facsimile mode
  @Default("isFacsimile")
  public var isFacsimile: Bool
  
  var count:Int = 0
  var currentPrio:Int = 5
  
  @Default("disabledCoachmarks")
  fileprivate var disabledCoachmarks: [CoachmarkItem]
  
  lazy var availableCoachmarkKeys: [String:Int] = {
    return getCurrentAvailableCoachmarkKeys()
  }()
  
  func getCurrentAvailableCoachmarkKeys() -> [String:Int] {
    let disabledCm = disabledCoachmarks
    let all = Coachmarks.all
    var ret : [String:Int] = [:]
    for cm in all {
      if disabledCm.contains(where: {$0.key == cm.key}){
        ret[cm.key] = 0
        continue
      }
      let prio = cm.prio
      ret[cm.key] = prio
      
      if currentPrio > prio {
        currentPrio = prio
      }
    }
    
    //ensure Facsimile coachmark not shown if already in facsimile view!
    if isFacsimile {
      ret[Coachmarks.IssueCarousel.pdfButton.key] = 0
    }
    
    ///set all coachmarks with a higher priority as currently disabled by setting -1
    ret.keys.forEach {
      let itmPrio = ret[$0] ?? 0
      if itmPrio == currentPrio {
        hasActiveCoachmarks = true
      }
      else if itmPrio > currentPrio  {
        ret[$0] = -1
      }
    }
    ///if none in current prio, wait 3 App Sessions to show more coachmarks
    if cmLastPrio != currentPrio {
      if cmSessionCount > 0 {
        ///0 on change/next start, 1 next start, reset to 0 && prio change ==2nd ==> 3rd available again!
        cmSessionCount = 0
        cmLastPrio = currentPrio
      }
      else {
        cmSessionCount += 1
      }
      hasActiveCoachmarks = false
    }
    
    if hasActiveCoachmarks == true {
      log("Available Coachmarks: \(ret.filter{$0.value == currentPrio}.keys.joined(separator: ", "))")
    }
    else {
      log("Coachmarks are not available. \(currentPrio)\(cmLastPrio)\(cmSessionCount)")
    }
    return ret
  }
  
  var hasActiveCoachmarks: Bool?
  
  func reset(){
    disabledCoachmarks = []
    currentPrio = 5
    count = 0
    cmSessionCount = 0
    cmLastPrio = 1
    availableCoachmarkKeys = getCurrentAvailableCoachmarkKeys()
  }
  
  func deactivateCoachmark(_ item: CoachmarkItem){
    if availableCoachmarkKeys[item.key] == 0 { return }
    availableCoachmarkKeys[item.key] = 0
    disabledCoachmarks.append(item)
  }
  
  func setShown(item: CoachmarkItem){
    deactivateCoachmark(item)
    count += 1
  }
  
  fileprivate func showCoachmarkIfNeeded(sender: CoachmarkVC){
    if UIAccessibility.isVoiceOverRunning { return }
    if sender.preventCoachmark { return }
    let activeCmKeys = availableCoachmarkKeys.filter({$0.value == currentPrio})
    if hasActiveCoachmarks == false { return }//ensure not to test before availableCoachmarkKeys set this!
    guard let item
            = sender.items.filter({ item in
              activeCmKeys.contains(where: {item.key ==  $0.key })
    }).first else { return }
    
    if let target = sender.targetView(for: item) {
      showCoachmark(sender: sender, target: target, item: item)
    }
    else if let alternativeTarget = sender.target(for: item) {
      showCoachmark(sender: sender, target: nil, item: item, alternativeTarget: alternativeTarget)
    }
    else {
      log("Not show coachmarks for: \(item.key)")
    }
  }
  
  var currentActiveCMVC: CoachmarkVC?
  
  func showCoachmark(sender: CoachmarkVC, target: UIView?, item: CoachmarkItem, alternativeTarget: (UIImage, [UIView], [CGPoint])? = nil) {
    guard let window = UIApplication.shared.delegate?.window else { return }
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
        self?.setShown(item: cv.item)
        self?.currentActiveCMVC = nil
      }
    }
  }
  
  static let shared = CoachmarksBusiness()
}
