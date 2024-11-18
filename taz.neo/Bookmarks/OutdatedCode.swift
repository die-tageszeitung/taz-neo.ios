//
//  OutdatedCode.swift
//  taz.neo
//
//  Created by Ringo Müller on 18.11.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import Foundation



/* FROM BOOKMARKS SWIFT */
/**
 
 Diskussion sind die Lesezeichen(Leseliste) ggf. weitere Listen Hörliste, Archiv, ... jetzt Feeds oder im Feed taz/lmd?
 
 Verbindung
 * ist es der gleiche Feed, ist die Verbindung via (regulärer) Issue bzw. Bookmark/Archiv/Hör Issue (nur eine, alles andere via Sections!!) viel einfacher
 * d.h. Cleanup, löschen einer Issue etc.  ist deutlich weniger Komplex (weil nur über eine Ebene, und Löschen von Ausgaben eh bereits vorhanden isT)
 * löschen via Feed ist komplexer, Fehler sind schwerer zu erkennen/debuggen Modellfehler aufwendiger zu beheben
 Pro eigener Feed:
 * was ist auf Serverseite? Wenn wir auf Serverseite die ganz große Interation hätten, dann müssten Nutzerdaten von Ausgabendaten getrennt sein und jeder Nutzer hätte seinen Feed....das werden wir aber so nicht haben, An der Schnittstelle (API, GraphQL) kann eine entsprechende Transformation stattfinden und findet bereits statt => Warum: deutliche Komplexitätsreduzierung
 
 @Norbert falls Wiederspruch:
 * * ich erinnere mich gut an 2-3 Debug Sessions, die wir gemeinsam via zoom gemacht haben, 4ALL: **das Modell ist komplex, wir brauchen ein gemeinsames verständniss davon, Pappnasen erzeugen massive teschnische Schuld und damit Arbeit in der Zukunft: wenn wir nicht aufpassen werden wir uns dann irgendwann eingestehen müssen: eine Weiterentwicklung macht keinen sinn, weil deutlich aufwändiger als Neuentwicklung, mehr als 70% der Arbeitszeit geht für Debuggng, Bugfixing drauf. Das muss nicht sein**
 
 
 HACKS:
 po (shared.bookmarkSection?.articles as? [StoredArticle])?.flatMap{$0.serverId}
 
 Status
 * Bookmark Feed is depreciated
 * lost Section's html after restart
 StoredFileEntry.fileNameExists(inDir:) Info:
   * Warning: File Leseliste.html exists but mtime and/or size are wrong 2024-08-29 08:24:41 +0000 !=? 2024-08-29 08:24:37 +0000 || 377 !=? 14
 ...datei muss generiert und bei appear neu geladen werden!
 tap auf Artikel geht nicht in Artikel
 * löschen Ausgabe
 * neu laden ausgabe?
 * Migration
 * wieso verschwinden artikel aus ihrem eigentlichen issue? ...und wann?
 
 * aktuelle Probleme?
 LADEFEHLER => DONE
 * entfernen aus Leseliste auf Artikelebene klappt nicht
 falscher bookmarks ordner wird noch vom bookmarks feed angelegt
 wenn ein Artikel in Section gebookmarkt ist, erscheint nach neustart der Stern nicht und er lässt sich nicht toggln
 
 kann ein Artikel in mehreren Sections der gleichen Ausgabe sein?
 Was passiert, wenn ein Artikel in einer Ausgabe gelöscht weird, weil die Ausgabe gelöscht wird?
 Wie vermeide ich dass ein Artikel von Ausgabe zu BM Ausgabe hin und her verschoben/Kopiert wird? Beim laden der Ausgabe neu geladen wird?
 Der ArtikelHTML+Bilder sollte an seinem Platz bleiben
 => d.h. Löschen nochmal überarbeiten!
 => reduce to overview sollte passen
 => remove unknown folders & co muss angepasst werden und um diese sachwen erweitert werden
 => delete issue muss angepasst werden
 ...crash war date nil wieso?... war aber beim löschen,
 
 
 nächste Herausforderung finden des Artikels und seiner ressourcen für ArticleVC, ist nicht in issue folder oder nicht in bookmark issue folder!?
 
 */

///Motivation: altes bookmark issue war virtuell und nicht in db, soll jetzt in db sein um ausgabenunabhängige lesezeichen zu haben
///Problem setze und entferne bookmark hat riesen overhead, sollte vielleicht nicht komplett im Model via Artikel gemacht werden, also hier ...halte dann hier auch das BookmarkIssue und die entsprechende Section vorrätig
///später mehrere Sections: Leseliste, archiv, hörliste....




/* BookmarkNC */

class Bmnc1 {
#warning("ToDo: bookmarked demo, delete issue; login")
//    Notification.receive("updatedDemoIssue") { [weak self] notif in
//      guard let self = self else { return }
//      self.bookmarkFeed
//      = BookmarkFeed.allBookmarks(feeder: self.feeder)
//      self.sectionVC.delegate = nil
//      self.sectionVC.delegate = self///trigger SectionVC.setup()
//    }

}

/* OLD AND UNUSED */
/* OLD AND UNUSED */
/* OLD AND UNUSED */


extension BookmarkNC {
  func setup() {
    Notification.receive(Const.NotificationNames.expiredAccountDateChanged) { [weak self] notif in
      guard TazAppEnvironment.hasValidAuth else { return }
      self?.reloadOpened()
    }
#warning("ToDo after refactor and issue independent bookmarks")
    /*
     there was a (particullary not) reproduceable bug:
     logged out > load demo issue > bookmark demo article > view in bookmark list
     > login in issue-overview
     1. > move to article in bookmarks > showed demo Article OR! full Article (depend on what?) AND showed Login Form
     2. > article in bookmark list was not clickable (list did not refreshed!)
     
     to load all articles fully is maybe too much because currently its needed to load all issues
     later with issue independent bookmark articles we can load all articles
     
     another bug: bookmark css was also after a few restarts not available.
     from testflight alpha > alpha
     not solved by various restarts @see error report by mail
     solved by start debug
     */
    
    Notification.receive(Const.NotificationNames.authenticationSucceeded) { [weak self] notif in
      guard TazAppEnvironment.hasValidAuth else { return }
      self?.reloadOpened()
    }
  }

extension BookmarkNC: ReloadAfterAuthChanged {
  public func reloadOpened(){
    /// UseCase: app reseted, unauth, bookmark demo Article
    /// view demo article in bookmark list, scroll down login
    guard TazAppEnvironment.hasValidAuth else { return }
    
    let lastIndex: Int? = (self.viewControllers.last as? ArticleVC)?.index
    var issuesToDownload:[StoredIssue] = []
//    for art in bookmarkFeed.issues?.first?.allArticles ?? [] {
//      if let sissue = art.primaryIssue as? StoredIssue,
//         sissue.status == .reduced,
//         issuesToDownload.contains(sissue) == false {
//        issuesToDownload.append(sissue)
//      }
//    }
        
//    func downloadNextIfNeeded(){
//      if let nextIssue = issuesToDownload.first {
//        self.feederContext.getCompleteIssue(issue: nextIssue,
//                                             isPages: false,
//                                             isAutomatically: false)
//      } else if let idx = lastIndex {
//        reopenArticleAtIndex(idx: idx)
//      } else {
////        self.bookmarkFeed
////        = BookmarkFeed.allBookmarks(feeder: self.feeder)
////        self.sectionVC.reload()
//        Notification.send(Const.NotificationNames.removeLoginRefreshDataOverlay)
//      }
//    }
    
//    Notification.receive("issue"){ notif in
//      ///ensure the issue download comes from here!
//      guard let issue = notif.object as? Issue else { return }
//      guard let issueIdx = issuesToDownload.firstIndex(where: {$0.date == issue.date})
//      else { return /* Issue Download from somewhere else */ }
//      issuesToDownload.remove(at: issueIdx)
//      downloadNextIfNeeded()
//    }
//    downloadNextIfNeeded()
  }
  
  private func reopenArticleAtIndex(idx: Int?){
//    self.bookmarkFeed
//    = BookmarkFeed.allBookmarks(feeder: self.feeder)
//    self.sectionVC.releaseOnDisappear()
//    self.sectionVC
//    = createSectionVC(openArticleAtIndex: idx)
//    self.viewControllers[0] = self.sectionVC
//    self.popToRootViewController(animated: true)
//    Notification.send(Const.NotificationNames.removeLoginRefreshDataOverlay)
  }
  
  public func reloadIfNeeded(article: Article?){
    guard let article = article,
          let reloadIssue = article.primaryIssue as? StoredIssue else { return }

    if article.html?.exists(inDir: article.dir.path) == false {
      loadReload(reloadIssue: reloadIssue)
    }
    else if reloadIssue.isReduced && TazAppEnvironment.hasValidAuth {
      loadReload(reloadIssue: reloadIssue)
    }
  }
  
  private func loadReload(reloadIssue: StoredIssue){
    let lastIndex: Int? = (self.viewControllers.last as? ArticleVC)?.index
    let snap = UIWindow.keyWindow?.snapshotView(afterScreenUpdates: false)
    WaitingAppOverlay.show(alpha: 1.0,
                           backbround: snap,
                           showSpinner: true,
                           titleMessage: "Aktualisiere Daten",
                           bottomMessage: "Bitte haben Sie einen Moment Geduld!",
                           dismissNotification: Const.NotificationNames.removeLoginRefreshDataOverlay)
    Notification.receive("issue"){[weak self] notif in
      ///ensure the issue download comes from here!
      guard let issue = notif.object as? Issue else { return }
      guard reloadIssue.date.issueKey == issue.date.issueKey else { return }
      self?.reopenArticleAtIndex(idx: lastIndex)
    }
    reloadOpened()
    onMainAfter {[weak self] in
      self?.popToRootViewController(animated: false)//there is a overlay
    }
  }
}
