//
//  FetchNewStatusHeader.swift
//  taz.neo
//
//  Created by Ringo Müller on 18.02.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// A View for show Update/Download Activity with a Label and a ActivityIndicatorView
// MARK: - StatusHeader
class FetchNewStatusHeader: UIView {
  
  ///Possible States
  enum status:String {
    case offline, online, fetchNewIssues, fetchMoreIssues, loadPreview, loadIssue, downloadError, none, stoppedLoadOvw, autoloadErrorNoWlan
    ///Message for the user
    var infoMessage:String? {
      get {
        switch self {
          case .fetchNewIssues:
            return "Suche nach neuen Ausgaben"
          case .fetchMoreIssues:
            return "Suche nach weiteren Ausgaben"
          case .loadPreview:
            return "Lade Vorschau"
          case .loadIssue:
            return "Lade Ausgabe"
          case .offline:
            return "Keine Internetverbindung"
          case .downloadError:
            return "Fehler beim Laden der Daten"
          case .autoloadErrorNoWlan:
            return "Automatischer Download fehlgeschlagen, kein WLAN"
          case .stoppedLoadOvw:
            return "Aktualisierung angehalten!"
          case .online: fallthrough;
          default:
            return nil
        }
      }
    }
    ///text color for the Label
    var textColor:UIColor {
      get {
        switch self {
          case .stoppedLoadOvw, .downloadError, .autoloadErrorNoWlan:
            return UIColor.red.withAlphaComponent(0.7)
          case .offline: fallthrough;
          case .online: fallthrough;
          default:
            return Const.Colors.appIconGrey
        }
      }
    }
    
    ///should show activity indicator e.g. for fetch and downloads
    var showActivity:Bool {
      get {
        switch self {
          case .fetchNewIssues, .fetchMoreIssues, .loadPreview, .loadIssue:
            return true
          default:
            return false
        }
      }
    }
  }/// eof: status
  
  ///indicates if status change animations are running, to wait for previous change done
  ///e.g. fast change from .fetchNewIssues to .none label may been hidden before it was shown
  private var animating = false {
    didSet {
      checkStatus()
    }
  }
  
  private var lastErrorShown:Date?
  
  private func checkStatus(){
    //let last error at least 5s
    if let last = lastErrorShown {
      let sec = Date().timeIntervalSince(last)
      if sec < 5 {
        onMain(after: 5 - sec + 1) { [weak self] in
          self?.checkStatus()
        }
        return
      }
    }
        
    while !animating {
      guard let next = nextStatus.pop() else { return }
      if next == currentStatus { continue }
      currentStatus = next
      return
    }
  }
  
  
  ///array to enque next status e.g. if an animation blocks the current change
  private var nextStatus:[status] = []
  /// private property to store currentStatus, on set it animates ui components
  private var _currentStatus:status = .none {
    didSet {
      let callback = { [weak self] in
          guard let self = self else { return }
          self.label.text = self.currentStatus.infoMessage
          self.label.textColor = self.currentStatus.textColor
          
          self.currentStatus.showActivity
            ? self.activityIndicator.startAnimating()
            : self.activityIndicator.stopAnimating()
          
          if self.label.text != nil {
            self.label.showAnimated(){ self.animating = false }
          } else{
            self.animating = false
          }
        }
      if label.isHidden {
        callback()
        return
      }
      
      label.hideAnimated() {
        callback()
      }
    }
  }
  
  /***
   .downloadError => .none Hide after 5s Activity Indicator Stop
   .downloadError => .loadPreview == loadPreview after 5s Activity Indicator enqueue
   .downloadError => .loadPreview => .downloadError => .loadPreview
   
   */
  
  
  var currentStatus:status {
    get { return _currentStatus }
    set {
      if currentStatus == .stoppedLoadOvw { return }//do not overwrite this important info
      if currentStatus == .fetchNewIssues && animating == true {
        animating = false //stop waiting for animation, allow next change
        nextStatus.append(newValue);
        return
      }
      if _currentStatus == newValue || nextStatus.last == newValue { return; }
      if animating { nextStatus.append(newValue); return; }
      if newValue == .downloadError || newValue == .autoloadErrorNoWlan { lastErrorShown = Date() }
      animating = true
      _currentStatus = newValue
    }
  }
  
  private lazy var activityIndicator = UIActivityIndicatorView()
  
  private lazy var label : UILabel = UILabel().contentFont().white().centerText()
  
  
  func setup(){
    addSubview(activityIndicator)
    addSubview(label)
    label.font = Const.Fonts.contentFont(size: 14)
    activityIndicator.color = .white
    activityIndicator.centerX()
    pin(activityIndicator.top, to: self.top, dist: Const.Dist.margin)
    
    pin(label.left, to: self.left, dist: Const.Dist.margin)
    pin(label.right, to: self.right, dist: -Const.Dist.margin)
    pin(label.top, to: activityIndicator.bottom, dist: Const.Dist.margin)
    pin(label.bottom, to: self.bottom, dist: 0)

    Notification.receive(UIApplication.willEnterForegroundNotification) { [weak self] _ in
      self?.animating = false
    }
  }
  
  override public init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required public init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
}
