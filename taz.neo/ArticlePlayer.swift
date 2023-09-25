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
  
  @Default("playbackRate")
  public var playbackRate: Double
  
  public var isOpen: Bool {
    userInterface.superview != nil
  }
  
  /// The audio player
  var aplayer: AudioPlayer
  var aPlayerPlayed = false
  
  func updatePlaying(){ isPlaying =  aplayer.isPlaying }
  
  var isPlaying: Bool = false {
    didSet {
      if oldValue == isPlaying {
        Notification.send(Const.NotificationNames.audioPlaybackStateChanged,
                          content: nil,
                          error: nil,
                          sender: self)
        return
      }
      userInterface.isPlaying = isPlaying
      Notification.send(Const.NotificationNames.audioPlaybackStateChanged,
                        content: nil,
                        error: nil,
                        sender: self)
      commandCenter.seekForwardCommand.isEnabled = isPlaying
      commandCenter.seekBackwardCommand.isEnabled = isPlaying
      //Must be enabled otherwise button is disabled, this happen on close!
      commandCenter.previousTrackCommand.isEnabled = isPlaying
      commandCenter.nextTrackCommand.isEnabled = isPlaying
      commandCenter.playCommand.isEnabled = true
    }
  }
  
  public func onEnd(closure: ((Error?)->())?) { _onEnd = closure }
  private var _onEnd: ((Error?)->())?
  
  var nextContent: [Content] = []
  var lastContent: [Content] = []
  
  var currentContent: Content? {
    didSet {
      let wasPaused = !aplayer.isPlaying && aplayer.file != nil
      aplayer.file = url(currentContent)
      
      aplayer.title = currentContent?.title
      userInterface.titleLabel.text = currentContent?.title
      
      ///album not shown on iOS 16, Phone in Lock Screen, CommandCenter, CommandCenter Extended Player
      aplayer.album = currentContent?.sectionTitle
      ?? "taz vom: \(currentContent?.primaryIssue?.validityDateText(timeZone: GqlFeeder.tz) ?? "-")"
      
      var authorsString: String? ///von Max Muster
      var issueString: String?///taz vom 1.2.2021
      
      if let authors = currentContent?.authors, !authors.isEmpty {
        var names: [String] = []
        for a in authors { if let n = a.name { names += n } }
        authorsString = "von " + names.joined(separator: ", ") + ""
      }
      
      if let i = currentContent?.primaryIssue {
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
      
      let articleImage = currentContent?.articleImage
      let issueImage = currentContent?.articleImage
      aplayer.addLogo = articleImage != nil
      aplayer.image = articleImage ?? issueImage
      userInterface.image = articleImage
      
      if aplayer.file != nil {
        userInterface.show()
        _ = commandCenter//setup if needed
        if !wasPaused { aplayer.play() }
        aPlayerPlayed = true
        self.userInterface.slider.value = 0.0
      }
      userInterface.updateUI()
      updatePlaying()
    }
  }
  
  private init() {
    aplayer = AudioPlayer()
    aplayer.resetNowPlayingInfo = false
    aplayer.setupCloseRemoteCommands = false
    aplayer.logoToAdd = UIImage(named: "AppIcon60x60")
    aplayer.onTimer { [weak self] in
      guard let item = self?.aplayer.currentItem else { return }
      self?.userInterface.totalSeconds = item.asset.duration.seconds
      self?.userInterface.currentSeconds = item.currentTime().seconds
    }
    aplayer.onEnd { [weak self] err in
      self?._onEnd?(err)
      self?.userInterface.currentSeconds = self?.userInterface.totalSeconds
      let resume = self?.nextContent.isEmpty == false
      self?.playNext()
      //ensure play next
      if resume { self?.aplayer.play()}
      self?.updatePlaying()
    }
    aplayer.onStateChange {[weak self] in
      ///handle  commandcenter: play, pause, stop, togglePlayPause firs too early so handle py own callback
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
    $playbackRate.onChange{[weak self] newValue in
      self?.aplayer.player?.rate = Float(newValue)
    }
  }
  
  @objc private func sliderChanged(sender: Any) {
    guard let item = self.aplayer.currentItem else { return }
    let pos:Double = item.asset.duration.seconds * Double(userInterface.slider.value)
    aplayer.currentTime = CMTime(seconds: pos, preferredTimescale: 600)
  }
  
  var touchDownActive = false
  
  @objc private func  forwardButtonTouchDownAction(sender: Any) {
    touchDownActive = true
    onMainAfter(0.5) {[weak self] in
      guard self?.touchDownActive == true else { return }
      self?.seekForeward()
    }
  }
  @objc private func forwardButtonTouchUpInsideAction(sender: Any) {
    seeking ? stopSeeking() :  playNext()
    touchDownActive = false
  }
  @objc private func forwardButtonTouchOutsideInsideAction(sender: Any) {
    seeking ? seekForeward() : nil
    touchDownActive = false
  }
  
  @objc private func backwardButtonTouchDownAction(sender: Any) {
    touchDownActive = true
    onMainAfter(0.5) {[weak self] in
      guard self?.touchDownActive == true else { return }
      self?.seekBackward()
    }
  }
  @objc private func backwardButtonTouchUpInsideAction(sender: Any) {
    seeking ? stopSeeking() :  playPrev()
    touchDownActive = false
  }
  @objc private func backwardButtonTouchOutsideInsideAction(sender: Any) {
    seeking ? seekBackward() : nil
    touchDownActive = false
  }
  
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
  
  func stopSeeking() {
    aplayer.player?.rate = Float(playbackRate)
    seeking = false
  }
  
  func seekForeward() {
    if seeking == true {
      stopSeeking()
      return
    }
    aplayer.player?.rate = 2.0
    seeking = true
    onMainAfter(1.3) {[weak self] in
      guard self?.seeking == true else { return }
      self?.aplayer.player?.rate = 4.0
    }
    onMainAfter(2.2) {[weak self] in
      guard self?.seeking == true else { return }
      self?.aplayer.player?.rate = 10.0
    }
  }
  
  func seekBackward() {
    if seeking == true {
      stopSeeking()
      return
    }
    aplayer.player?.rate = -2.0
    seeking = true
    onMainAfter(1.3) {[weak self] in
      guard self?.seeking == true else { return }
      self?.aplayer.player?.rate = -4.0
    }
    onMainAfter(2.2) {[weak self] in
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
  
  private func url(_ content: Content?) -> String? {
    if let article = content as? Article,
       let baseUrl = (article as? SearchArticle)?.originalIssueBaseURL
                     ?? article.primaryIssue?.baseUrl,
       let afn = article.audio?.fileName {
      return "\(baseUrl)/\(afn)"
    }
    return nil
  }
  
  func deleteHistory(){ lastContent = []   }
  
  func playNext() {
    if nextContent.count == 0 {
      //no next do not destroy ui
      self.aplayer.currentTime = CMTime(seconds: 0.0, preferredTimescale: 600)
      userInterface.currentSeconds = 0.0
      pause()
      if let issue = (currentContent as? Article)?.primaryIssue {
        self.play(issue: issue, startFromArticle: nil, enqueueType: .replaceCurrent)
      }
      return
    }
    if let currentArticle = currentContent {
      lastContent.append(currentArticle)
    }
    ///warning replace current article remembers pause e.g. paused & skip through the playlist should not start
    currentContent = nextContent.pop()
  }
  
  func playPrev() {
    if self.aplayer.currentTime.seconds > 5.0 {
      //restart current
      self.aplayer.currentTime = CMTime(seconds: 0.0, preferredTimescale: 600)
      return
    }
    if lastContent.count == 0 {
      //no prev do not destroy ui
      self.aplayer.currentTime = CMTime(seconds: 0.0, preferredTimescale: 600)
      pause()
      return
    }
    if let currentArticle = currentContent {
      nextContent.insert(currentArticle, at: 0)
    }
    currentContent = lastContent.popLast()
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
    guard let currentArticle = currentContent else { return }
    Notification.send(Const.NotificationNames.gotoArticleInIssue, content: currentArticle, sender: self)
  }
  /// Stop the currently being played article
  private func close() {
    nextContent = []
    lastContent = []
    aplayer.close()
    currentContent = nil
    commandCenter.previousTrackCommand.isEnabled = false
    commandCenter.nextTrackCommand.isEnabled = false
    commandCenter.playCommand.isEnabled = false
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
  }
  
  public func play(issue:Issue,
                   startFromArticle: Article?,
                   enqueueType: PlayerEnqueueType,
                   loadIssueIfNeeded: Bool = true){
    
    let feederContext = TazAppEnvironment.sharedInstance.feederContext
    
    if let storedIssue = issue as? StoredIssue,
       feederContext?.needsUpdate(issue: issue) ?? true {
      let msg = enqueueType == .replaceCurrent
      ? "Die Wiedergabe wird nach Download der Ausgabe gestartet."
      : "Die Wiedergabeliste wird nach Download der Ausgabe ergänzt."
      if loadIssueIfNeeded {
        Toast.show(msg)
      }
      Notification.receiveOnce("issueStructure", from: issue) { [weak self] notif in
        self?.play(issue: issue,
                   startFromArticle: startFromArticle,
                   enqueueType: enqueueType,
                   loadIssueIfNeeded: false)
      }
      if loadIssueIfNeeded {
        feederContext?.getCompleteIssue(issue: storedIssue,
                                        isPages: false,
                                        isAutomatically: false)
      }
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
        nextContent.append(contentsOf: arts)
        isPlaying ? nil : playNext()
      case .enqueueNext:
        nextContent.insert(contentsOf: arts, at: 0)
        isPlaying ? nil : playNext()
      case .replaceCurrent:
        nextContent = arts
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
    if ArticlePlayer.singleton.isPlaying == false && ArticlePlayer.singleton.nextContent.count == 0 {
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

fileprivate extension Content{
  var articleImage:UIImage? { (self as? Article)?.image }
  
  var issueImage:UIImage? {
    if let art = self as? Article {
      return art.primaryIssue?.image
    }
    if let sect = self as? Section {
      return sect.primaryIssue?.image
    }
    return nil
  }
}
