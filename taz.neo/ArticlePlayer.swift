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
  
  var nextArticles: [Article] = [] {
    didSet {
      if aPlayerPlayed == false { return }
      commandCenter.nextTrackCommand.isEnabled = nextArticles.count > 0
    }
  }
  var lastArticles: [Article] = [] {
    didSet {
      if aPlayerPlayed == false { return }
      commandCenter.previousTrackCommand.isEnabled = lastArticles.count > 0
    }
  }
  var currentArticle: Article? {
    didSet {
      let wasPaused = !aplayer.isPlaying && aplayer.file != nil
      #warning("may set state after no one is available anymore")
      aplayer.file = url(currentArticle)
      
      aplayer.title = currentArticle?.title
      userInterface.titleLabel.text = currentArticle?.title
      
      aplayer.album = currentArticle?.sectionTitle
      ?? "taz vom: \(currentArticle?.primaryIssue?.validityDateText(timeZone: GqlFeeder.tz) ?? "-")"
      
      var authorsString: String?
      
      if let authors = currentArticle?.authors, !authors.isEmpty {
        var names: [String] = []
        for a in authors { if let n = a.name { names += n } }
        authorsString = names.joined(separator: ", ")
      }
      aplayer.artist = authorsString
      userInterface.authorLabel.text = authorsString
      
      let img: UIImage? = currentArticle?.image ?? currentArticle?.primaryIssue?.image
      aplayer.image = img
      userInterface.image = img
      
      if aplayer.file != nil {
        userInterface.show()
        if !wasPaused { aplayer.play() }
        aPlayerPlayed = true
        self.userInterface.slider.value = 0.0
  
      }
      userInterface.isPlaying = aplayer.isPlaying
    }
  }
  
  private init() {
    aplayer = AudioPlayer()
    aplayer.onTimer { [weak self] in
      guard let item = self?.aplayer.currentItem else { return }
      self?.userInterface.totalSeconds = item.asset.duration.seconds
      self?.userInterface.currentSeconds = item.currentTime().seconds
    }
    aplayer.onEnd { [weak self] _ in
      self?.userInterface.currentSeconds = self?.userInterface.totalSeconds
    }
    
    userInterface.slider.addTarget(self,
                                   action: #selector(sliderChanged),
                                   for: .valueChanged)
//    aplayer.setupRemoteCommands = false//use custom ones here!
  }
  
  @objc private func sliderChanged(sender: Any) {
    #warning("todo")
//    aplayer.player?.pause()
    print("slider changed: \(sender) value\(userInterface.slider.value)")
  }
                                   
                                   
  private static var _singleton: ArticlePlayer? = nil
  private lazy var userInterface: ArticlePlayerUI = {
    let v =  ArticlePlayerUI()
    v.onToggle {[weak self] in self?.toggle() }
    v.onClose{[weak self] in self?.close() }
    v.onForward{[weak self] in self?.playNext() }
    v.onBack{[weak self] in self?.playPrev() }
    return v
  }()
  
  ///iOs Lock Screen (CarPlay, Widgets) Media Controlls
  private lazy var commandCenter: MPRemoteCommandCenter = {
    UIApplication.shared.beginReceivingRemoteControlEvents()
    let cc = MPRemoteCommandCenter.shared()
    cc.previousTrackCommand.removeTarget(nil)
    cc.nextTrackCommand.removeTarget(nil)
    cc.pauseCommand.removeTarget(nil)
    cc.playCommand.removeTarget(nil)
    cc.changePlaybackPositionCommand.removeTarget(nil)
    
    cc.pauseCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
      print("pause")
      return .success
    }
    
    cc.seekForwardCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
      print("seekForwardCommand at \(self?.aplayer.currentTime)")
      return .success
    }
    
    cc.seekBackwardCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
      print("seekBackwardCommand at \(self?.aplayer.currentTime)")
      return .success
    }
    cc.playCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
      print("PLAY")
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
    cc.changePlaybackPositionCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
      let pos = (event as! MPChangePlaybackPositionCommandEvent).positionTime
      self?.aplayer.currentTime = CMTime(seconds: pos, preferredTimescale: 600)
      return .success
    }
    
    cc.playCommand.isEnabled = true
    cc.pauseCommand.isEnabled = true
    /**
     cc.skipBackwardCommand.isEnabled = false
     cc.skipForwardCommand.isEnabled = false
     */
    return cc
  }()
  
  
  /// There is only one ArticlePlayer per app
  public static var singleton: ArticlePlayer {
    if _singleton == nil { _singleton = ArticlePlayer() }
    return _singleton!
  }
  
  /// Define closure to call when playing has been finished
  private func onEnd(closure: ((Error?)->())?) { aplayer.onEnd(closure: closure) }
  
  private func url(_ art: Article?) -> String? {
    guard let article = art,
          let baseUrl
            = article.primaryIssue?.baseUrl
            ?? (article as? SearchArticle)?.originalIssueBaseURL,
          let afn = article.audio?.fileName else { return nil }
    return "\(baseUrl)/\(afn)"
  }
  
  func deleteHistory(){ lastArticles = []   }
  
  func playNext() {
    if let currentArticle = currentArticle {
      lastArticles.append(currentArticle)
    }
    currentArticle = nextArticles.pop()
  }
  
  func playPrev() {
    if let currentArticle = currentArticle {
      nextArticles.insert(currentArticle, at: 0)
    }
    currentArticle = lastArticles.popLast()
  }
  
  /// Checks whether the passed Article is currently being played
  private func isPlaying(_ article: Article? = nil) -> Bool {
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
    userInterface.isPlaying = aplayer.isPlaying
  }
  
  /// Starts the current Article (after pause())
  private func start() {
    aplayer.play()
    userInterface.isPlaying = aplayer.isPlaying
  }
  
  /// Toggles start()/pause()
  private func toggle() {
    aplayer.toggle()
    userInterface.isPlaying = aplayer.isPlaying
  }
  
  
//  /// This toggle starts playing of the passed Article if this Article is not
//  /// currently being played. If it is playing, it uses the simple toggle().
//  private func toggle(_ article: Article) {
//    if isPlaying(article) { toggle() }
//    else { play(article) }
//  }
  
  /// Stop the currently being played article
  private func close() {
    nextArticles = []
    lastArticles = []
    aplayer.close()
    currentArticle = nil
  }
  
  public func play(issue:StoredIssue, startFromArticle: Article?, enqueueType: PlayerEnqueueType){
    
    let feederContext = TazAppEnvironment.sharedInstance.feederContext
    
    if feederContext?.needsUpdate(issue: issue) ?? true {
      let msg = enqueueType == .replaceCurrent
      ? "Die Wiedergabe wird nach Download der Ausgabe gestartet."
      : "Die Wiedergabeliste wird nach Download der Ausgabe ergänzt."
      Toast.show(msg)
      Notification.receiveOnce("issue", from: issue) { [weak self] notif in
        self?.play(issue: issue,
                   startFromArticle: startFromArticle,
                   enqueueType: enqueueType)
      }
      feederContext?.getCompleteIssue(issue: issue,
                                      isPages: false,
                                      isAutomatically: false)
    }
    var arts:[Article] = issue.allArticles
    if let startFromArticle = startFromArticle {
      arts = Array(arts.drop { art in
        art.isEqualTo(otherArticle: startFromArticle)
      })
    }
    arts.removeAll{ $0.audio?.fileName == nil }
    
    switch enqueueType {
      case .enqueueLast:
        nextArticles.append(contentsOf: arts)
      case .enqueueNext:
        nextArticles.insert(contentsOf: arts, at: 0)
      case .replaceCurrent:
        nextArticles = arts
        playNext()
    }
  }
  
  
} // ArticlePlayer


extension ArticlePlayer {
  func contextMenu(for issue:StoredIssue) -> UIMenu {
    ///some of the icons are only available iOS 16+
    let playImgName = "play.fill"
    let nextImgName = "text.line.first.and.arrowtriangle.forward"
    let lastImgName = "text.line.last.and.arrowtriangle.forward"
    //next and last icons may need to be added to custom assets
    let playImg = UIImage(name: playImgName) ?? UIImage(named: playImgName)
    let nextImg = UIImage(name: nextImgName) ?? UIImage(named: nextImgName)
    let lastImg = UIImage(name: lastImgName) ?? UIImage(named: lastImgName)
    
    let playAllNow = UIAction(title: "Wiedergabe",
                              image: playImg) {[weak self] _ in
      self?.play(issue: issue, startFromArticle: nil, enqueueType: .replaceCurrent)
    }
    let enqueueNext = UIAction(title: "Als nächstes wiedergeben",
                               image: nextImg){[weak self] _ in
      self?.play(issue: issue, startFromArticle: nil, enqueueType: .enqueueNext)
    }
    
    let enqueueLast = UIAction(title: "Zuletzt wiedergeben",
                               image: lastImg) {[weak self] _ in
      self?.play(issue: issue, startFromArticle: nil, enqueueType: .enqueueNext)
    }
    return  UIMenu(title: "",
                   options: .displayInline,
                   children:[playAllNow, enqueueNext, enqueueLast])
    //    without header there is no scrolling
    //    return  UIMenu(title: "Vorlesefunktion",
    //                   options: .displayInline,
    //                   children:[playAllNow, enqueueNext, enqueueLast])
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
