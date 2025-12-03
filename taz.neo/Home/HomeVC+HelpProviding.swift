//
//  HomeVC+HelpProviding.swift
//  taz.neo
//
//  Created by Ringo Müller on 02.10.25.
//  Copyright © 2025 taz. All rights reserved.
//

import NorthLib
import UIKit


extension HomeVC: HelpProviding{
  ///Helper for Icon Help
  fileprivate var issueStatusSymbols: UIView? {
    let wrapper = UIView()
    let label1  = UILabel("Heruntergeladen: Die Ausgabe ist vollständig geladen und offline verfügbar.")
    let icon1 = UIImageView(image: UIImage(named: "checkmark")?.withRenderingMode(.alwaysOriginal))
    let label2  = UILabel("Noch nicht komplett: Tippen Sie auf die Ausgabe, um fehlende Inhalte automatisch zu laden.")
    let icon2 = UIImageView(image: UIImage(named: "download")?.withRenderingMode(.alwaysOriginal))
    let label3  = UILabel("Wird geladen: Die Ausgabe lädt gerade herunter.")
    let icon3 = UIImageView(image: UIImage(named: "downloading")?.withRenderingMode(.alwaysOriginal))
    let label4  = UILabel("Weitelesen: Tippen Sie auf dieses Symbol, um an der zuletzt gelesenen Stelle weiterzumachen.")
    let icon4 = UIImageView(image: UIImage(named: "bookmark")?.withRenderingMode(.alwaysOriginal))
    
    label1.contentFont(size: Const.Size.SmallerFontSize).white()
    label2.contentFont(size: Const.Size.SmallerFontSize).white()
    label3.contentFont(size: Const.Size.SmallerFontSize).white()
    label4.contentFont(size: Const.Size.SmallerFontSize).white()
    
    wrapper.addSubview(label1)
    wrapper.addSubview(icon1)
    wrapper.addSubview(label2)
    wrapper.addSubview(icon2)
    wrapper.addSubview(label3)
    wrapper.addSubview(icon3)
    wrapper.addSubview(label4)
    wrapper.addSubview(icon4)
    
    pin(icon1.left, to: wrapper.left)
    pin(label1.left, to: icon1.right, dist: 9.0)
    pin(icon2.left, to: wrapper.left)
    pin(label2.left, to: icon1.right, dist: 9.0)
    pin(icon3.left, to: wrapper.left)
    pin(label3.left, to: icon1.right, dist: 9.0)
    pin(icon4.left, to: wrapper.left)
    pin(label4.left, to: icon1.right, dist: 9.0)
    
    pin(label1.right, to: wrapper.right)
    pin(label2.right, to: wrapper.right)
    pin(label3.right, to: wrapper.right)
    pin(label4.right, to: wrapper.right)
    
    pin(label1.top, to: wrapper.top, dist: 0)
    pin(label2.top, to: label1.bottom, dist: 8.0)
    pin(label3.top, to: label2.bottom, dist: 8.0)
    pin(label4.top, to: label3.bottom, dist: 8.0)
    pin(label4.bottom, to: wrapper.bottom)
    
    icon1.pinSize(CGSize(width: 24.0, height: 24.0))
    icon2.pinSize(CGSize(width: 24.0, height: 24.0))
    icon3.pinSize(CGSize(width: 20.0, height: 20.0))
    icon4.pinSize(CGSize(width: 24.0, height: 24.0))
    
    pin(icon1.top, to: label1.top)
    pin(icon2.top, to: label2.top)
    pin(icon3.top, to: label3.top)
    pin(icon4.top, to: label4.top)
    wrapper.pinWidth(350, priority: .defaultLow)
    return wrapper
  }
  
  ///Helper for Tabbar Items
  fileprivate var tabbarItems: [UIView] {
    var views: [UIView] = []
    if let tabBar = self.tabBarController?.tabBar {
      for (_, view) in tabBar.subviews.enumerated() {
        if let control = view as? UIControl {
          views.append(control)
        }
      }
    }
    return views
  }
  
  var helpItems: [HelpItem] {
    get {
      let tabbarItems = self.tabbarItems
      
      let wellcomeItem = HelpItem(title:"Willkommen in der taz App!",
                                       text: "Entdecken Sie die digitale Ausgabe der taz: Blättern Sie durch die Zeitung, speichern Sie Artikel oder lassen Sie sich Texte vorlesen.")
            
      let viewModeItem = HelpItem(title:"Ansichtssache",
                                  accessibilityTitle: "Hilfe für den Home Screen, erstes Element: Schalter, Darstellungsoptionen",
                                       text: "Wechseln Sie zwischen App- und Zeitungsansicht, wählen Sie Karussell- oder Kachel-Layout und springen Sie direkt zu Ausgaben bis zurück ins Jahr 2011.",
                                       isCircleCutout: true,
                                       circleCutoutInsetAdjustment: -14.0,
                                       targetView: self.viewModeButton)
      if let img = UIImage(named: "Img-HomeViewMenu"){
        let view = UIImageView(image: img)
        view.contentMode = .scaleAspectFit
        view.pinHeight(190)
        viewModeItem.contentView = view
      }
      
      
      let issueStatus
      = HelpItem(title:"Symbole in der Ausgabenübersicht",
                 text: "",
                 accessibilityLabelText: "Voiceover gibt den aktuellen Status der Ausgaben an, es werden Symbole wie ein Download-Icon zum herunterladen, das Häckchen für heruntergeladen oder das Weiterlesen Icon angezeigt")
      issueStatus.contentView = self.issueStatusSymbols
      if isHomeTiles == false {
        issueStatus.targetView = self.downloadButton.indicator
        issueStatus.isCircleCutout = true
      }
    
      let calendar = HelpItem(title:"Datumsauswahl",
                               text: "Hier können Sie Ausgaben bis 2011 nach Datum aufrufen. Artikel aus noch älteren Ausgaben finden Sie über die Suche.",
                               isCircleCutout: true,
                               targetView: calenderImageView)
      
      let home = HelpItem(title:"Home",
                          accessibilityTitle: "Home, Tabbar Item",
                          text: "Wenn Sie hier tippen, gelangen Sie jederzeit zurück zur Startseite. Bei erneutem Tipp springt die Ansicht zur aktuellen Ausgabe.",
                          isCircleCutout: true,
                          targetView: tabbarItems.valueAt(0))
      let bookmarks = HelpItem(title:"Leseliste",
                               accessibilityTitle: "Leseliste, Tabbar Item",
                               text: "Hier finden Sie alle Ihre gespeicherten Artikel.",
                               isCircleCutout: true,
                               targetView: tabbarItems.valueAt(1))
      let search = HelpItem(title:"Suche",
                            accessibilityTitle: "Suche, Tabbar Item",
                            text: "Durchsuchen Sie alle Ausgaben der taz von 1981 bis heute – nach Stichworten, Namen oder Autor:innen.",
                            isCircleCutout: true,
                            targetView: tabbarItems.valueAt(2))
      
      let helpButton = (navigationController?.parent as? MainTabVC)?.helpButton
      
      let helpItem = HelpItem(title:"Hilfe!",
                                       text: "In vielen Bereichen finden Sie das Fragezeichen-Symbol. Tippen Sie darauf, um die Funktionen des aktuellen Bildschirms erklärt zu bekommen.\nProbieren Sie die Hilfe auch auf anderen Bildschirmen aus.",
                                   isCircleCutout: true,
                                   circleCutoutInsetAdjustment: 0,
                              targetView: helpButton?.helpIconImageView)

      let scrollItem = HelpItem(title:"Ausgaben durchstöbern",
                                       text: "Wischen Sie auf den Ausgaben nach rechts und links um zu älteren oder neueren Ausgaben zu kommen.")
      if let img = UIImage(name: "arrowshape.left.arrowshape.right"){
        let wrapper = UIView()
        let view = UIImageView(image: img)
        if isHomeTiles {
          view.transform = CGAffineTransform(rotationAngle: .pi / 2)
          scrollItem.text = "Wischen Sie auf den Ausgaben von unten nach oben um zu älteren Ausgaben zu kommen."
        }
        view.tintColor = .white
        view.contentMode = .center
        view.pinWidth(80)
        wrapper.addSubview(view)
        pin(view.top, to: wrapper.top, dist: 18)
        pin(view.bottom, to: wrapper.bottom)
        view.centerX(dist: 20)
        scrollItem.contentView = wrapper
      }
      
      let homeMenuItem = HelpItem(title:"Für Profis: das Kontextmenü",
                                       text: "Tippen Sie länger auf eine Ausgabe, um das Kontextmenü mit weiteren nützlichen Funktionen zu öffnen.")
      if let img = UIImage(named: "Img-HomeMenu"){
        let view = UIImageView(image: img)
        view.contentMode = .scaleAspectFit
        view.pinHeight(200)
        homeMenuItem.contentView = view
      }
      
      
      var items = [viewModeItem, issueStatus, scrollItem, home, bookmarks, search, helpItem, homeMenuItem]
      
      if isHomeTiles == false {
        items.insert(calendar, at: 2)///after issueStatus
      }
      
      if isInitialStartup {
        isInitialStartup = false
        items.insert(wellcomeItem, at: 0)
      }
      return items
    }
  }
}
