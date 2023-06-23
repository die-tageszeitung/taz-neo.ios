//
//  ArticlePlayer.swift
//  taz.neo
//
//  Created by Norbert Thies on 15.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib
import MediaPlayer


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
        aplayer.onTimer { [weak self] in
          guard let item = self?.aplayer.currentItem else { return }
          self?.userInterface.slider.value
          = Float(item.currentTime().seconds / item.asset.duration.seconds)
        }
      }
      userInterface.isPlaying = aplayer.isPlaying
    }
  }
  
  private init() {
    aplayer = AudioPlayer()
//    aplayer.setupRemoteCommands = false//use custom ones here!
  }
  
  private static var _singleton: ArticlePlayer? = nil
  private lazy var userInterface: UserInterface = {
    let v =  UserInterface()
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
  
  public func play(issue:Issue, startFromArticle: Article?, enqueueType: PlayerEnqueueType){
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
  func contextMenu(for issue:Issue) -> UIMenu {
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

enum PlayerEnqueueType { case replaceCurrent, enqueueNext, enqueueLast}

class UserInterface: UIView {
  
  var image: UIImage? {
    didSet {
      imageView.image = image
      if image == nil {
        imageAspectConstraint?.isActive = false
        imageWidthConstraint?.isActive = true
        imageLeftConstraint?.constant = 0.0
      }
      else {
        imageWidthConstraint?.isActive = false
        imageAspectConstraint?.isActive = false
        imageAspectConstraint = imageView.pinAspect(ratio: 1.0)
        imageLeftConstraint?.constant = Const.Size.DefaultPadding
      }
      UIView.animate(withDuration: 0.3) {[weak self] in
        self?.layoutIfNeeded()
      }
    }
  }
  
  private var backClosure: (()->())?
  private var forwardClosure: (()->())?
  private var toggleClosure: (()->())?
  private var closeClosure: (()->())?
  
  fileprivate func onBack(closure: @escaping ()->()) {
    backClosure = closure
  }
  
  fileprivate func onForward(closure: @escaping ()->()){
    forwardClosure = closure
  }
  
  fileprivate func onToggle(closure: @escaping ()->()){
    toggleClosure = closure
  }
  
  fileprivate func onClose(closure: @escaping ()->()){
    closeClosure = closure
  }
  
  private lazy var imageView: UIImageView = {
    let v = UIImageView()
    v.clipsToBounds = true
    v.onTapping(closure: { [weak self] _ in self?.maximize() })
    return v
  }()
  
  lazy var titleLabel: UILabel = {
    let lbl = UILabel()
    lbl.boldContentFont(size: 13).white()
    lbl.onTapping(closure: { [weak self] _ in self?.maximize() })
    return lbl
  }()
  
  lazy var authorLabel: UILabel = {
    let lbl = UILabel()
    lbl.contentFont(size: 12).white()
    lbl.onTapping(closure: { [weak self] _ in self?.maximize() })
    return lbl
  }()
  
  lazy var closeButton: Button<ImageView> = {
    let btn = Button<ImageView>()
    btn.onPress { [weak self] _ in
      self?.removeFromSuperview()
      self?.closeClosure?()
    }
    btn.activeColor = .white
    btn.color = Const.Colors.appIconGrey
    btn.buttonView.symbol = "xmark"
    return btn
  }()
  
  lazy var slider: UISlider = {
    let slider = UISlider()
    let thumb = UIImage.circle(diam: 8.0, color: .white)
    slider.setThumbImage(thumb, for: .normal)
    slider.setThumbImage(thumb, for: .highlighted)
    slider.minimumTrackTintColor = .white
    return slider
  }()
  
  
  lazy var minimizeButton: Button<ImageView> = {
    let btn = Button<ImageView>()
    btn.onPress { [weak self] _ in self?.minimize() }
    btn.pinSize(CGSize(width: 35, height: 35))
    btn.activeColor = .white
    btn.color = Const.Colors.appIconGrey
    btn.buttonView.symbol = "chevron.down"
    return btn
  }()
  
  lazy var toggleButton: Button<ImageView> = {
    let btn = Button<ImageView>()
    btn.onPress { [weak self] _ in self?.toggleClosure?() }
    btn.pinSize(CGSize(width: 36, height: 36))
    btn.activeColor = .white
    btn.color = Const.Colors.appIconGrey
    btn.buttonView.symbol = "pause.fill"
    return btn
  }()
  
  var isPlaying: Bool = false {
    didSet {
      toggleButton.buttonView.symbol = isPlaying ? "pause.fill" : "play.fill"
    }
  }
  
  lazy var backButton: Button<ImageView> = {
    let btn = Button<ImageView>()
    btn.onPress { [weak self] _ in self?.backClosure?() }
    btn.pinSize(CGSize(width: 35, height: 35))
    btn.activeColor = .white
    btn.color = Const.Colors.appIconGrey
    btn.buttonView.symbol = "backward.fill"
    //btn.buttonView.symbol = "gobackward.15"
    return btn
  }()
  
  var backButtonEnabled = true {
    didSet {
      backButton.isEnabled = backButtonEnabled
      backButton.alpha = backButtonEnabled ? 1.0 : 0.5
    }
  }
  var forwardButtonEnabled = true {
    didSet {
      forwardButton.isEnabled = forwardButtonEnabled
      forwardButton.alpha = forwardButtonEnabled ? 1.0 : 0.5
    }
  }
  
  lazy var forwardButton: Button<ImageView> = {
    let btn = Button<ImageView>()
    btn.onPress { [weak self] _ in self?.forwardClosure?() }
    btn.pinSize(CGSize(width: 35, height: 35))
    btn.activeColor = .white
    btn.color = Const.Colors.appIconGrey
    btn.buttonView.symbol = "forward.fill"
    //btn.buttonView.symbol = "goforward.15"
    return btn
  }()
  
  func show(){
    if self.superview != nil {
      error("already displayed")
      return
    }
    guard let window = UIWindow.keyWindow else {
      error("No Key Window")
      return
    }
    window.addSubview(self)
    pin(self.right, to: window.rightGuide(), dist: -Const.Size.DefaultPadding)
    pin(self.bottom, to: window.bottomGuide(), dist: -60.0)
  }
  
  
  func minimize(){
    ///ignore if min not needed
  }
  
  func maximize(){
    ///ignore if max
    print("maximize...")
  }
  
  func setup2(){
    self.addSubview(imageView)
    self.addSubview(titleLabel)
    self.addSubview(authorLabel)
    self.addSubview(closeButton)
    self.addSubview(minimizeButton)
    self.addSubview(slider)
    self.addSubview(imageView)
    self.addSubview(toggleButton)
    
    slider.isHidden = true
    minimizeButton.isHidden = true
    
    self.layer.cornerRadius = 5.0 //max: 13.0
    
    let cSet = pin(imageView, to: self, dist: 10.0, exclude: .right)
    imageLeftConstraint = cSet.left
    
    imageWidthConstraint = imageView.pinWidth(1)
    imageWidthConstraint?.isActive = false
    
    imageAspectConstraint = imageView.pinAspect(ratio: 1.0)
    imageView.contentMode = .scaleAspectFill
    
    pin(titleLabel.top, to: imageView.top, dist: -1.0)
    pin(authorLabel.bottom, to: imageView.bottom)
    
    pin(titleLabel.left, to: imageView.right, dist: 10.0)
    pin(authorLabel.left, to: imageView.right, dist: 10.0)
    
    pin(closeButton, to: self, dist: 14.0, exclude: .left)
    closeButton.pinAspect(ratio: 1.0)
    
    pin(toggleButton.centerY, to: closeButton.centerY)
    pin(toggleButton.right, to: closeButton.left, dist: -22.0)
    
    pin(titleLabel.right, to: toggleButton.left, dist: -22.0)
    pin(authorLabel.right, to: toggleButton.left, dist: -22.0)
    
    titleLabel.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)
    authorLabel.setContentCompressionResistancePriority(.fittingSizeLevel, for: .horizontal)
    
    self.backgroundColor = Const.Colors.darkSecondaryBG
    self.pinHeight(50)
    widthConstraint = self.pinWidth(200)
    self.updateWidth()
    
    Notification.receive(Const.NotificationNames.viewSizeTransition) {   [weak self] notification in
      guard let newSize = notification.content as? CGSize else { return }
      self?.updateWidth(width: newSize.width)
    }
    
    /**
     backward.fill
     forward.fill
     
     list.bullet   mit 5px padding corner radius ca 5px if list open
     
     
     */
    
  }
  
  func setup(){
    self.addSubview(imageView)
    self.addSubview(titleLabel)
    self.addSubview(authorLabel)
    self.addSubview(closeButton)
    self.addSubview(minimizeButton)
    self.addSubview(slider)
    self.addSubview(imageView)
    self.addSubview(toggleButton)
    self.addSubview(backButton)
    self.addSubview(forwardButton)
    
    self.layer.cornerRadius = 13.0
    
    pin(minimizeButton.top, to: self.top, dist: 10.0)
    pin(minimizeButton.right, to: self.right, dist: -10.0)
    
    pin(imageView.left, to: self.left, dist: 10.0)
    pin(imageView.right, to: self.right, dist: -10.0)
    pin(imageView.top, to: minimizeButton.bottom, dist: 10.0)

    //Aspect and hight is critical e.g. tv tower vs panorama
    imageView.pinAspect(ratio: 0.75)
    imageView.contentMode = .scaleAspectFit
    
    pin(titleLabel.left, to: self.left, dist: 10.0)
    pin(titleLabel.right, to: self.right, dist: -10.0)
    pin(titleLabel.top, to: imageView.bottom, dist: 10.0)

    pin(authorLabel.left, to: self.left, dist: 10.0)
    pin(authorLabel.right, to: self.right, dist: -10.0)
    pin(authorLabel.top, to: titleLabel.bottom, dist: 10.0)
    
    pin(slider.left, to: self.left, dist: 10.0)
    pin(slider.right, to: self.right, dist: -10.0)
    pin(slider.top, to: authorLabel.bottom, dist: 10.0)
    
    toggleButton.centerX()
    pin(toggleButton.top, to: slider.bottom, dist: 10.0)
    pin(toggleButton.bottom, to: self.bottom, dist: -10.0)

    pin(backButton.right, to: toggleButton.left, dist: -30.0)
    pin(forwardButton.left, to: toggleButton.right, dist: 30.0)
    
    pin(backButton.centerY, to: toggleButton.centerY)
    pin(forwardButton.centerY, to: toggleButton.centerY)
    
    self.backgroundColor = Const.Colors.darkSecondaryBG
    widthConstraint = self.pinWidth(200)
    self.updateWidth()
    
    Notification.receive(Const.NotificationNames.viewSizeTransition) {   [weak self] notification in
      guard let newSize = notification.content as? CGSize else { return }
      self?.updateWidth(width: newSize.width)
    }
    
    /**

     
     list.bullet   mit 5px padding corner radius ca 5px if list open
     
     
     */
    
  }
  
  
  var widthConstraint: NSLayoutConstraint?
  var imageWidthConstraint: NSLayoutConstraint?
  var imageLeftConstraint: NSLayoutConstraint?
  var imageAspectConstraint: NSLayoutConstraint?
  
  func updateWidth(width:CGFloat = UIWindow.keyWindow?.bounds.size.width ?? UIScreen.shortSide){
    widthConstraint?.constant = min(300, width - 2*Const.Size.DefaultPadding)
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

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
