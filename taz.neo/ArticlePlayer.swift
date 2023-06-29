//
//  ArticlePlayer.swift
//  taz.neo
//
//  Created by Norbert Thies on 15.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import NorthLib
import MediaPlayer


enum PlayerEnqueueType { case replaceCurrent, enqueueNext, enqueueLast}

/// The ArticlePlayer plays one or more Articles as audio streams
class ArticlePlayer: DoesLog {
  
  /// The audio player
  var aplayer: AudioPlayer
  var aPlayerPlayed = false
  
  func updatePlaying(){ isPlaying =  aplayer.isPlaying }
  
  var isPlaying: Bool = false {
    didSet {
      if oldValue == isPlaying { return }
      userInterface.isPlaying = isPlaying
      Notification.send(Const.NotificationNames.audioPlaybackStateChanged,
                        content: isPlaying,
                        error: nil,
                        sender: self)
      commandCenter.seekForwardCommand.isEnabled = isPlaying
      commandCenter.seekBackwardCommand.isEnabled = isPlaying
    }
  }
  
  var acticeTargetView: UIView? {
    didSet { userInterface.acticeTargetView = acticeTargetView }}
  
  public func onEnd(closure: ((Error?)->())?) { _onEnd = closure }
  private var _onEnd: ((Error?)->())?
  
  var nextArticles: [Article] = []
  var lastArticles: [Article] = []
  
  var currentArticle: Article? {
    didSet {
      let wasPaused = !aplayer.isPlaying && aplayer.file != nil
      aplayer.file = url(currentArticle)
      
      aplayer.title = currentArticle?.title
      userInterface.titleLabel.text = currentArticle?.title
      
      ///album not shown on iOS 16, Phone in Lock Screen, CommandCenter, CommandCenter Extended Player
      aplayer.album = currentArticle?.sectionTitle
      ?? "taz vom: \(currentArticle?.primaryIssue?.validityDateText(timeZone: GqlFeeder.tz) ?? "-")"
      
      var authorsString: String? ///von Max Muster
      var issueString: String?///taz vom 1.2.2021
      
      if let authors = currentArticle?.authors, !authors.isEmpty {
        var names: [String] = []
        for a in authors { if let n = a.name { names += n } }
        authorsString = "von " + names.joined(separator: ", ") + ""
      }
      
      if let i = currentArticle?.primaryIssue {
        issueString = "\(i.isWeekend ? "wochentaz" : "taz") vom \(i.date.short)"
      }
      
      if let authorsString = authorsString, let issueString = issueString {
        aplayer.artist = "\(authorsString) (\(issueString))"//von Max Muster (taz vom 29.6.2023)
        userInterface.authorLabel.text = authorsString //von Max Muster
      }
      else if let authorsString = authorsString {//von Max Muster
        aplayer.artist = authorsString
        userInterface.authorLabel.text = authorsString
      }
      else if let issueString = issueString {
        aplayer.artist = issueString//taz vom 1.2.2021
        userInterface.authorLabel.text = nil//empty
      }
      else {
        aplayer.artist = nil
        userInterface.authorLabel.text = nil
      }
      
      let img: UIImage? = currentArticle?.image ?? currentArticle?.primaryIssue?.image
      aplayer.addLogo = currentArticle?.image != nil
      aplayer.image = img
      userInterface.image = currentArticle?.image
      
      if aplayer.file != nil {
        userInterface.show()
        _ = commandCenter//setup if needed
        if !wasPaused { aplayer.play() }
        aPlayerPlayed = true
        self.userInterface.slider.value = 0.0
      }
      updatePlaying()
    }
  }
  
  private init() {
    aplayer = AudioPlayer()
    aplayer.logoToAdd = UIImage(named: "AppIcon60x60")
    aplayer.onTimer { [weak self] in
      guard let item = self?.aplayer.currentItem else { return }
      self?.userInterface.totalSeconds = item.asset.duration.seconds
      self?.userInterface.currentSeconds = item.currentTime().seconds
    }
    aplayer.onEnd { [weak self] err in
      self?._onEnd?(err)
      self?.userInterface.currentSeconds = self?.userInterface.totalSeconds
      let resume = self?.nextArticles.isEmpty == false
      self?.playNext()
      //ensure play next
      if resume { self?.aplayer.play()}
      self?.updatePlaying()
    }
    
    userInterface.slider.addTarget(self,
                                   action: #selector(sliderChanged),
                                   for: .valueChanged)
    userInterface.forwardButton.addTarget(self,
                                   action: #selector(forwardButtonTouchDownAction),
                                   for: .touchDown)
    userInterface.forwardButton.addTarget(self,
                                   action: #selector(forwardButtonTouchUpInsideAction),
                                   for: .touchUpInside)
    userInterface.forwardButton.addTarget(self,
                                   action: #selector(forwardButtonTouchOutsideInsideAction),
                                   for: .touchUpOutside)
    userInterface.backButton.addTarget(self,
                                   action: #selector(backwardButtonTouchDownAction),
                                   for: .touchDown)
    userInterface.backButton.addTarget(self,
                                   action: #selector(backwardButtonTouchUpInsideAction),
                                   for: .touchUpInside)
    userInterface.backButton.addTarget(self,
                                   action: #selector(backwardButtonTouchOutsideInsideAction),
                                   for: .touchUpOutside)
  }
  
  @objc private func sliderChanged(sender: Any) {
    guard let item = self.aplayer.currentItem else { return }
    let pos:Double = item.asset.duration.seconds * Double(userInterface.slider.value)
    aplayer.currentTime = CMTime(seconds: pos, preferredTimescale: 600)
  }
  
  var touchDownActive = false
  
  @objc private func  forwardButtonTouchDownAction(sender: Any) {
    touchDownActive = true
    onThreadAfter(0.5) {[weak self] in
      guard self?.touchDownActive == true else { return }
      self?.seekForeward()
    }
  }
  @objc private func forwardButtonTouchUpInsideAction(sender: Any) {
    seeking ? seekForeward() :  playNext()
    touchDownActive = false
  }
  @objc private func forwardButtonTouchOutsideInsideAction(sender: Any) {
    seeking ? seekForeward() : nil
    touchDownActive = false
  }
  
  @objc private func backwardButtonTouchDownAction(sender: Any) {
    touchDownActive = true
    onThreadAfter(0.5) {[weak self] in
      guard self?.touchDownActive == true else { return }
      self?.seekBackward()
    }
  }
  @objc private func backwardButtonTouchUpInsideAction(sender: Any) {
    seeking ? seekBackward() :  playPrev()
    touchDownActive = false
  }
  @objc private func backwardButtonTouchOutsideInsideAction(sender: Any) {
    seeking ? seekBackward() : nil
    touchDownActive = false
  }
  
  ///No way to do something like this!
//  @objc private func forwardButtonAction(sender: Any?, forEvent event: UIEvent?) {
//    switch (seeking, event) {
//      case let (true, event) where event == UIControl.Event.touchCancel):
//        seekForeward()
////      case true, .touchUpInside:
////        seekForeward()
////      case false, .touchDown:
////        seekForeward()
////      case _, .touchUpInside:
////        playNext()
//      default:
//        print("true")
//    }
//  }
                                   
  private static var _singleton: ArticlePlayer? = nil
  private lazy var userInterface: ArticlePlayerUI = {
    let v =  ArticlePlayerUI()
    v.onToggle {[weak self] in self?.toggle() }
    v.onClose{[weak self] in self?.close() }
    v.onMaxiItemTap{[weak self] in self?.gotoCurrentArticleInIssue() }
    return v
  }()
  
  ///iOs Lock Screen (CarPlay, Widgets) Media Controlls
  private lazy var commandCenter: MPRemoteCommandCenter = {
    UIApplication.shared.beginReceivingRemoteControlEvents()
    let cc = MPRemoteCommandCenter.shared()
    cc.previousTrackCommand.removeTarget(nil)
    cc.nextTrackCommand.removeTarget(nil)
    cc.seekForwardCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
      self?.seekForeward()
      return .success
    }
    cc.seekBackwardCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
      self?.seekBackward()
      return .success
    }
    cc.previousTrackCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
      self?.playPrev()
      return .success
    }
    cc.nextTrackCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
      self?.playNext()
      return .success
    }
    return cc
  }()
  
  var seeking = false
  
  func seekForeward() {
    if seeking == true {
      aplayer.player?.rate = 1.0
      seeking = false
      return
    }
    
    aplayer.player?.rate = 2.0
    seeking = true
    onThreadAfter(2.0) {[weak self] in
      guard self?.seeking == true else { return }
      self?.aplayer.player?.rate = 4.0
    }
    onThreadAfter(4.0) {[weak self] in
      guard self?.seeking == true else { return }
      self?.aplayer.player?.rate = 10.0
    }
  }
  
  func seekBackward() {
    if seeking == true {
      aplayer.player?.rate = 1.0
      seeking = false
    }
    
    aplayer.player?.rate = -2.0
    seeking = true
    onThreadAfter(2.0) {[weak self] in
      guard self?.seeking == true else { return }
      self?.aplayer.player?.rate = -4.0
    }
    onThreadAfter(4.0) {[weak self] in
      guard self?.seeking == true else { return }
      self?.aplayer.player?.rate = -10.0
    }
  }
  
  
  /// There is only one ArticlePlayer per app
  public static var singleton: ArticlePlayer {
    if _singleton == nil { _singleton = ArticlePlayer() }
    return _singleton!
  }
    
  func canPlay(_ art: Article?) -> Bool {
    return url(art) != nil
  }
  
  private func url(_ art: Article?) -> String? {
    guard let article = art,
          let baseUrl
            = (article as? SearchArticle)?.originalIssueBaseURL
            ?? article.primaryIssue?.baseUrl,
          let afn = article.audio?.fileName else { return nil }
    return "\(baseUrl)/\(afn)"
  }
  
  func deleteHistory(){ lastArticles = []   }
  
  func playNext() {
    if nextArticles.count == 0 {
      //no next do not destroy ui
      self.aplayer.currentTime = CMTime(seconds: 0.0, preferredTimescale: 600)
      pause()
      return
    }
    if let currentArticle = currentArticle {
      lastArticles.append(currentArticle)
    }
    ///warning replace current article remembers pause e.g. paused & skip through the playlist should not start
    currentArticle = nextArticles.pop()
  }
  
  func playPrev() {
    if self.aplayer.currentTime.seconds > 5.0 {
      //restart current
      self.aplayer.currentTime = CMTime(seconds: 0.0, preferredTimescale: 600)
      return
    }
    if lastArticles.count == 0 {
      //no prev do not destroy ui
      self.aplayer.currentTime = CMTime(seconds: 0.0, preferredTimescale: 600)
      pause()
      return
    }
    if let currentArticle = currentArticle {
      nextArticles.insert(currentArticle, at: 0)
    }
    currentArticle = lastArticles.popLast()
  }
  
  /// Checks whether the passed Article is currently being played
  func isPlaying(_ article: Article? = nil) -> Bool {
    guard aplayer.isPlaying else { return false }
    if let art = article {
      guard let url = url(art) else { return false }
      return url == aplayer.file
    }
    else { return true }
  }
  
  /// Pauses the current Article play
  private func pause() {
    aplayer.stop()
    updatePlaying()
  }
  
  /// Starts the current Article (after pause())
  private func start() {
    aplayer.play()
    updatePlaying()
  }
  
  /// Toggles start()/pause()
  private func toggle() {
    aplayer.toggle()
    updatePlaying()
  }
  
  /// Toggles start()/pause()
  private func gotoCurrentArticleInIssue() {
    guard let currentArticle = currentArticle else { return }
    Notification.send(Const.NotificationNames.gotoArticleInIssue, content: currentArticle, sender: self)
  }
  /// Stop the currently being played article
  private func close() {
    nextArticles = []
    lastArticles = []
    aplayer.close()
    currentArticle = nil
    commandCenter.previousTrackCommand.isEnabled = false
    commandCenter.nextTrackCommand.isEnabled = false
  }
  
  public func play(issue:Issue, startFromArticle: Article?, enqueueType: PlayerEnqueueType){
    
    let feederContext = TazAppEnvironment.sharedInstance.feederContext
    
    if let storedIssue = issue as? StoredIssue,
       feederContext?.needsUpdate(issue: issue) ?? true {
      let msg = enqueueType == .replaceCurrent
      ? "Die Wiedergabe wird nach Download der Ausgabe gestartet."
      : "Die Wiedergabeliste wird nach Download der Ausgabe ergänzt."
      Toast.show(msg)
      Notification.receiveOnce("issue", from: issue) { [weak self] notif in
        self?.play(issue: issue,
                   startFromArticle: startFromArticle,
                   enqueueType: enqueueType)
      }
      feederContext?.getCompleteIssue(issue: storedIssue,
                                      isPages: false,
                                      isAutomatically: false)
    }
    
    var arts:[Article] = issue.allArticles
    if let startFromArticle = startFromArticle,
      let idx = issue.allArticles.firstIndex(where: { art in art.isEqualTo(otherArticle: startFromArticle) }),
    idx < arts.count {
      arts = Array(arts[idx...])
    }
    arts.removeAll{ $0.audio?.fileName == nil }
    
    switch enqueueType {
      case .enqueueLast:
        nextArticles.append(contentsOf: arts)
        isPlaying ? nil : playNext()
      case .enqueueNext:
        nextArticles.insert(contentsOf: arts, at: 0)
        isPlaying ? nil : playNext()
      case .replaceCurrent:
        nextArticles = arts
        playNext()
    }
  }
} // ArticlePlayer



extension Article {
  func contextMenu() -> MenuActions? {
    guard let issue = self.primaryIssue  else { return nil }
    let menu = MenuActions()
    menu.addMenuItem(title: "Wiedergabe",
             icon: "play.fill",
             closure: {_ in
      ArticlePlayer.singleton.play(issue: issue,
                 startFromArticle: self,
                 enqueueType: .replaceCurrent)
    })
    
    menu.addMenuItem(title: "Als nächstes wiedergeben",
             icon: "text.line.first.and.arrowtriangle.forward",
             closure: {_ in
      ArticlePlayer.singleton.play(issue: issue,
                 startFromArticle: self,
                 enqueueType: .enqueueNext)
    })
    
    menu.addMenuItem(title: "Zuletzt wiedergeben",
             icon: "text.line.last.and.arrowtriangle.forward",
             closure: {_ in
      ArticlePlayer.singleton.play(issue: issue,
                 startFromArticle: self,
                 enqueueType: .enqueueNext)
    })
    return menu
  }
}

extension BookmarkIssue {
  func contextMenu(group: Int) -> MenuActions {
    return _contextMenu(group:group)
  }
}

extension StoredIssue {
  func contextMenu(group: Int) -> MenuActions {
    return _contextMenu(group:group)
  }
}
extension Issue {
  func _contextMenu(group: Int) -> MenuActions {
    
    let menu = MenuActions()
    
    menu.addMenuItem(title: "Wiedergabe",
                     icon: "play.fill",
                     group: group,
                     closure: {_ in
      ArticlePlayer.singleton.play(issue: self,
                                        startFromArticle: nil,
                                        enqueueType: .replaceCurrent)
    })
    if ArticlePlayer.singleton.isPlaying == false && ArticlePlayer.singleton.nextArticles.count == 0 {
      return menu
    }
    menu.addMenuItem(title: "Als nächstes wiedergeben",
                     icon: "text.line.first.and.arrowtriangle.forward",
                     group: group,
                     closure: {_ in
      ArticlePlayer.singleton.play(issue: self,
                                        startFromArticle: nil,
                                        enqueueType: .enqueueNext)
    })
    
    menu.addMenuItem(title: "Zuletzt wiedergeben",
                     icon: "text.line.last.and.arrowtriangle.forward",
                     group: group,
                     closure: {_ in
      ArticlePlayer.singleton.play(issue: self,
                                        startFromArticle: nil,
                                        enqueueType: .enqueueNext)
    })
    return menu
  }
}


// MARK: - Helper
fileprivate extension Article {
  var image:UIImage? {
    guard let fn = images?.first?.fileName else { return nil }
    let path = "\(self.dir.path)/\(fn)"
    return UIImage(contentsOfFile: path)
  }
}

fileprivate extension Issue {
  var image:UIImage? {
    guard let momentImageUrl
            = TazAppEnvironment.sharedInstance.feederContext?.storedFeeder.smallMomentImageName(issue: self)
    else { return nil }
    return UIImage(contentsOfFile: momentImageUrl)
    
  }
}
