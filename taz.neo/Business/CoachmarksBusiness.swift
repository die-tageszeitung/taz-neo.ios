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
  var circleCutoutInsetAdjustment: CGFloat?
  var targetView: UIView?
  var contentView: UIView?
  
  init(title: String, text: String, isCircleCutout: Bool = false, circleCutoutInsetAdjustment:CGFloat? = nil, targetView: UIView? = nil) {
    self.title = title
    self.text = text
    self.isCircleCutout = isCircleCutout
    self.circleCutoutInsetAdjustment = circleCutoutInsetAdjustment
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
  
  func showHelp(sender: HelpProviding){
    guard let helpSender = sender as? HelpProviding else { return }
    guard let window = UIApplication.shared.delegate?.window else { return }
    
    ///show layer
      let helpView = HelpView()
      helpView.items = helpSender.items
      helpView.frame = window?.bounds ?? .zero // oder mit Auto Layout Constraints
      
      helpView.alpha = 0.0
      window?.addSubview(helpView)
      
      UIView.animate(withDuration: 0.7,
                     delay: 0,
                     options: UIView.AnimationOptions.curveEaseInOut,
                     animations: {
        helpView.alpha = 1.0
                     }, completion: { [weak self] (_) in
                      if helpView.isTopmost == false {
                        window?.bringSubviewToFront(helpView)
                      }
                     })
      helpView.onClose {[weak self]  in
        UIView.animate(withDuration: 0.7,
                       delay: 0,
                       options: UIView.AnimationOptions.curveEaseInOut,
                       animations: {
          helpView.alpha = 0.0
                       }, completion: {(_) in
//                         helpView.targetView = nil
                         helpView.removeFromSuperview()
                
                        })
      }
  }
  static let shared = CoachmarksBusiness()
}
