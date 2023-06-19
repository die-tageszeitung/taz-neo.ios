//
//  ArticlePlayer.swift
//  taz.neo
//
//  Created by Norbert Thies on 15.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// The ArticlePlayer plays one or more Articles as audio streams
class ArticlePlayer: DoesLog {
  
  /// The audio player
  public var aplayer: AudioPlayer
  
  /// The base URL to stream audio files from
  public var baseUrl: String?
  
  private init() {
    aplayer = AudioPlayer()
  }
  
  private static var _singleton: ArticlePlayer? = nil
  private lazy var userInterface: UserInterface = {
    let v =  UserInterface()
    v.onToggle {[weak self] in self?.toggle() }
    v.onClose{[weak self] in self?.stop(); v.removeFromSuperview() }
    return v
  }()
  
  
  /// There is only one ArticlePlayer per app
  public static var singleton: ArticlePlayer {
    if _singleton == nil { _singleton = ArticlePlayer() }
    return _singleton!
  }
  
  /// Define closure to call when playing has been finished
  public func onEnd(closure: ((Error?)->())?) { aplayer.onEnd(closure: closure) }
  
  /// Returns true if the passed Article can be played
  /// currently only Articles referencing audio files can be played
  public func canPlay(art: Article) -> Bool { art.audio != nil }
  
  private func url(_ art: Article) -> String? {
    guard let baseUrl = self.baseUrl, canPlay(art: art) else { return nil }
    return "\(baseUrl)/\(art.audio!.fileName)"
  }
  
    /// Plays the passed Article
  public func play(issue: Issue, art: Article, sectionName: String) {
    guard let url = url(art) else { return }
    aplayer.file = url
    if let title = art.title {
      aplayer.title = title
      userInterface.titleLabel.text = title
    }
    aplayer.album = sectionName
    if let authors = art.authors, !authors.isEmpty {
      var names: [String] = []
      for a in authors { if let n = a.name { names += n } }
      aplayer.artist = names.joined(separator: ", ")
      userInterface.authorLabel.text = names.joined(separator: ", ")
    }
    if let images = art.images, !images.isEmpty, 
       let fn = images.first?.fileName {
      let dir = issue.feed.feeder.issueDir(issue: issue).path
      debug("issue.date: \(issue.date), issueDir: \(dir)")
      let path = "\(dir)/\(fn)"
      let img = UIImage(contentsOfFile: path)
      if img == nil { 
        error("Can't load image \(path)") 
        let file = File(path)
        if file.exists { log("File exists, size: \(file.size)") }
        else { log("File doesn't exist") }
      }
      aplayer.image = img
      userInterface.image = img
    }
    else {
      aplayer.image = nil
      userInterface.image = nil
    }
    userInterface.show()
    aplayer.play()
  }
  
  /// Checks whether the passed Article is currently being played
  public func isPlaying(art: Article? = nil) -> Bool {
    guard aplayer.isPlaying else { return false }
    if let art = art {
      guard let url = url(art) else { return false }
      return url == aplayer.file
    }
    else { return true }
  }
  
  /// Pauses the current Article play
  public func pause() { aplayer.stop() }
  
  /// Starts the current Article (after pause())
  public func start() { aplayer.play() }
  
  /// Toggles start()/pause()
  public func toggle() { aplayer.toggle() }
  
  /// This toggle starts playing of the passed Article if this Article is not
  /// currently being played. If it is playing, it uses the simple toggle().
  public func toggle(issue: Issue, art: Article, sectionName: String) {
    if isPlaying(art: art) { toggle() }
    else { play(issue: issue, art: art, sectionName: sectionName) }
  }
  
  /// Stop the currently being played article
  public func stop() { aplayer.close() }
  
} // ArticlePlayer

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
  
  public func onBack(closure: @escaping ()->()) {
    backClosure = closure
  }
  
  public func onForward(closure: @escaping ()->()){
    forwardClosure = closure
  }
  
  public func onToggle(closure: @escaping ()->()){
    toggleClosure = closure
  }
    
  public func onClose(closure: @escaping ()->()){
    closeClosure = closure
  }
  
  private lazy var imageView: UIImageView = {
    let v = UIImageView()
    v.clipsToBounds = true
    return v
  }()

  lazy var titleLabel: UILabel = {
    let lbl = UILabel()
    lbl.boldContentFont(size: 13).white()
    return lbl
  }()
  
  lazy var authorLabel: UILabel = {
    let lbl = UILabel()
    lbl.contentFont(size: 12).white()
    return lbl
  }()
  
  lazy var closeButton: Button<ImageView> = {
    let btn = Button<ImageView>()
    btn.onPress { [weak self] _ in self?.closeClosure?() }
//    backButton.pinSize(CGSize(width: 35, height: 35))
    btn.activeColor = .white
    btn.color = Const.Colors.iconButtonInactive
    btn.buttonView.symbol = "xmark"
    return btn
  }()
  
  lazy var slider: UISlider = {
    let slider = UISlider()
    return slider
  }()

  
  lazy var minimizeButton: Button<ImageView> = {
    let btn = Button<ImageView>()
    btn.onPress { [weak self] _ in self?.minimize() }
    btn.pinSize(CGSize(width: 35, height: 35))
    btn.activeColor = .white
    btn.color = Const.Colors.iconButtonInactive
    btn.buttonView.symbol = "chevron.down"
    return btn
  }()
  
  lazy var toggleButton: Button<ImageView> = {
    let btn = Button<ImageView>()
    btn.onPress { [weak self] _ in self?.toggleClosure?() }
    btn.pinSize(CGSize(width: 20, height: 20))
    btn.activeColor = .white
    btn.color = Const.Colors.iconButtonInactive
    btn.buttonView.symbol = "pause.fill"
    return btn
  }()
  
  lazy var backButton: Button<ImageView> = {
    let btn = Button<ImageView>()
    btn.onPress { [weak self] _ in self?.backClosure?() }
    btn.pinSize(CGSize(width: 35, height: 35))
    btn.activeColor = .white
    btn.color = Const.Colors.iconButtonInactive
    btn.buttonView.symbol = "gobackward.15"
    return btn
  }()
  
  lazy var forwardButton: Button<ImageView> = {
    let btn = Button<ImageView>()
    btn.onPress { [weak self] _ in self?.forwardClosure?() }
    btn.pinSize(CGSize(width: 35, height: 35))
    btn.activeColor = .white
    btn.color = Const.Colors.iconButtonInactive
    btn.buttonView.symbol = "goforward.15"
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
    
  }
  
  func maximize(){
    
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
