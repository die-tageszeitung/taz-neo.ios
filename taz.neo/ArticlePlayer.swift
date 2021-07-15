//
//  ArticlePlayer.swift
//  taz.neo
//
//  Created by Norbert Thies on 15.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import Foundation
import NorthLib

/// The ArticlePlayer plays one or more Articles as audio streams
class ArticlePlayer {
  
  /// The audio player
  public var aplayer: AudioPlayer
  
  /// The base URL to stream audio files from
  public var baseUrl: String?
  
  private init() {
    aplayer = AudioPlayer()
  }
  
  private static var _singleton: ArticlePlayer? = nil

  /// There is only one ArticlePlayer per app
  public static var singleton: ArticlePlayer {
    if _singleton == nil { _singleton = ArticlePlayer() }
    return _singleton!
  }
  
  /// Returns true if the passed Article can be played
  /// currently only Articles referencing audio files can be played
  public func canPlay(art: Article) -> Bool { art.audio != nil }
  
  private func url(_ art: Article) -> String? {
    guard let baseUrl = self.baseUrl, canPlay(art: art) else { return nil }
    return "\(baseUrl)/\(art.audio!.fileName)"
  }
  
  /// Plays the passed Article
  public func play(art: Article, sectionName: String) {
    guard let url = url(art) else { return }
    aplayer.file = url
    if let title = art.title { aplayer.title = title }
    aplayer.album = sectionName
    aplayer.play()
  }
  
  /// Checks whether the passed Article is currently being played
  public func isPlaying(art: Article) -> Bool {
    guard let url = url(art) else { return false }
    return url == aplayer.file
  }
  
  /// Pauses the current Article play
  public func pause() { aplayer.stop() }
  
  /// Starts the current Article (after pause())
  public func start() { aplayer.play() }
  
  /// Toggles start()/pause()
  public func toggle() { aplayer.toggle() }
  
  /// This toggle starts playing of the passed Article if this Article is not
  /// currently being played. If it is playing, it uses the simple toggle().
  public func toggle(art: Article, sectionName: String) {
    if isPlaying(art: art) { toggle() }
    else { play(art: art, sectionName: sectionName) }
  }
  
} // ArticlePlayer
