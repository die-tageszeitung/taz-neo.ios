//
//  ArticleDB+SaveErrorhandling.swift
//  taz.neo
//
//  Created by Ringo Müller on 11.12.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import CoreData
import NorthLib
import UIKit

extension ArticleDB {
  /// Save the singleton's context
  public static func save() {
    singleton.save { err in Self.handleSaveError(error: err) }
  }
  
  private static func handleSaveError(error: NSError) {
    singleton.log("Fehler beim Speichern: \(error.localizedDescription)")
    
    var failedIssues: [PersistentIssue] = []
    var hasUnknownSource: Bool = false
    
    // Fehlerhafte Objekte identifizieren
    if let detailedErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
      for detailedError in detailedErrors {
        if let object = detailedError.userInfo[NSValidationObjectErrorKey] as? NSManagedObject {
          if let issue = relatedIssueFor(for: object) {
            failedIssues.append(issue)
          }
          else { hasUnknownSource = true }
        }
      }
    } else if let object = error.userInfo[NSValidationObjectErrorKey] as? NSManagedObject {
      if let issue = relatedIssueFor(for: object) {
        failedIssues.append(issue)
      }
      else { hasUnknownSource = true }
    }
    ///Array/Set to have unique dates
    handleError(for: Array(Set(failedIssues)), hasUnknownSource: hasUnknownSource)
    ///Test reset compleete database
    //handleError(for: [], hasUnknownSource: hasUnknownSource)
  }
  
  private static func handleError(for failedIssues: [PersistentIssue], hasUnknownSource: Bool){
    guard ArticleDB.singleton.isShowingDbErrorInfo == false else {
      singleton.log("Not handleError for \(failedIssues.count) issues; hasUnknownSource: \(hasUnknownSource)")
      return
    }
    singleton.log("handleError for \(failedIssues.count) issues; hasUnknownSource: \(hasUnknownSource)")
    ArticleDB.singleton.isShowingDbErrorInfo = true
    
    var text = ""
    var deleteIssueText: String?
    var cancelText: String = "Abbrechen"
    
    if failedIssues.count == 1 {
        text = "Eine defekte Ausgabe wurde in der Datenbank gefunden.\n Möchten Sie die defekte Ausgabe vom \(failedIssues.first!.date?.short ?? "-") löschen?"
      deleteIssueText = "Ausgabe löschen"
    }
    else if failedIssues.count > 1 {
      text = "Es wurden \(failedIssues.count) defekte Ausgaben in der Datenbank gefunden. Möchten Sie diese Ausgaben löschen?"
      deleteIssueText = "Ausgaben löschen"
    }
    else {
      text = "Die Datenbank weist Fehler auf und kann aktuell nicht gespeichert werden. Sie können die Datenbank zurückzusetzen oder versuchen den Fehler durch laden bzw. löschen der betroffenen Ausgaben bzw. Lesezeichen manuell zu beheben."
      cancelText = "Fehler selbst beheben"
    }
    
    text.append("\nDiese Meldung erscheint bei jedem Speichervorgang, bis der Fehler behoben ist.")
    
    var actions: [UIAlertAction] = []
    
    if let deleteIssueText = deleteIssueText {
      actions.append( Alert.action(deleteIssueText, style: .destructive) { _ in
        for issue in failedIssues {
          Notification.send("issueDelete", content: issue.date)
          issue.delete()
        }
        singleton.log("deleted issues save")
        onMainAfter(1.0) {
          ArticleDB.save()
        }
      })
    } else {
      actions.append( Alert.action("Datenbank zurücksetzen", style: .destructive) { _ in
        Alert.confirm(title: "Datenbank zurücksetzen?",
                      message: "Dadurch werden alle Lesezeichen und geladenen Ausgaben gelöscht. Dieser Vorgang kann nicht rückgängig gemacht werden. Die App muss im Anschluss neu gestartet werden.\n\nMöchten Sie die Datenbank wirklich zurücksetzen?") { reset in
          singleton.log("reset db: \(reset)")
          if reset {
            TazAppEnvironment.sharedInstance.reset(isDelete: true)
          }
          ///else error comes with next save again!
        }
      })
    }
    Alert.actionSheet(message: text, actions: actions, cancelTitle: cancelText) {
      ArticleDB.singleton.isShowingDbErrorInfo = false
    }
  }
  
  private static func relatedIssueFor(for object: NSManagedObject) -> PersistentIssue? {
      switch object {
        case let article as PersistentArticle:
          singleton.log("found article: \(article), issue count: \(article.issues?.count ?? 0) first issueDate: \((article.issues?.allObjects.first as? PersistentIssue)?.date?.short ?? "-")")
          return article.issues?.allObjects.first as? PersistentIssue
      default:
          singleton.log("found unknown object: \(object)")
          return nil
      }
  }
}
