//
//  LMdPageArticleCell.swift
//  taz.neo
//
//  Created by Ringo Müller on 11.01.24.
//  Copyright © 2024 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

/// self sizing cell with some labels and boockmark icon
class LMdPageArticleCell: UICollectionViewCell, LMdSliderCell {
  
  let starFill = UIImage(named: "star-fill")
  let star = UIImage(named: "star")
  
  let titleLabel = UILabel()
  let teaserLabel = UILabel()
  let authorLabel = UILabel()
  private let bookmarkButton = UIImageView()
  private var bookmarkIcon: UIImage? {
    didSet {
      guard oldValue != bookmarkIcon else { return }
      self.setNeedsLayout()
      self.setNeedsDisplay()
    }
  }
  
  /// Helper to prevent Simultaneous accesses to article, but modification requires exclusive access.
  /// on bookmarking and receive notification
  var articleIdentifier: String?
  
  var article: Article? {
    didSet {
      titleLabel.attributedText = article?.title?.attributed(lineHeightMultiple: 1.2)
      teaserLabel.attributedText = article?.teaser?.attributed(lineHeightMultiple: 1.4)
      ///authors & readingDuration
      var autors = article?.authors() ?? ""
      if autors.length > 0 {
        autors = autors.prepend("von ")
        autors.append("  ")
      }

      let attributedString = NSMutableAttributedString(string: autors)

      if let rd = article?.readingDuration {
        let timeString
        = NSMutableAttributedString(string: "\(rd) min")
        let trange = NSRange(location: 0, length: timeString.length)
        let thinFont = Const.Fonts.font(name: Const.Fonts.lmdBenton, size: 12)
        timeString.addAttribute(.font, value: thinFont, range: trange)
        timeString.addAttribute(.foregroundColor, value: Const.Colors.appIconGrey, range: trange)
        timeString.addAttribute(.backgroundColor, value: UIColor.clear, range: trange)
        attributedString.append(timeString)
      }
      
      let style = NSMutableParagraphStyle()
      style.lineHeightMultiple = 1.4
      attributedString.addAttribute(NSAttributedString.Key.paragraphStyle, 
                                    value: style,
                                    range: NSRange(location: 0,
                                                   length: attributedString.length))
      authorLabel.text = ""
      authorLabel.lmdArnhem(italic: true)
      authorLabel.textColor = Const.SetColor.taz2(.text).color
      authorLabel.attributedText = attributedString
      
      bookmarkButton.image = article?.hasBookmark ?? false ? starFill : star
      bookmarkButton.tintColor = Const.Colors.appIconGrey
      articleIdentifier = article?.html?.name
      bookmarkButton.isHidden
      = article?.html?.name == article?.primaryIssue?.imprint?.html?.name
    }
  }
  
  override func prepareForReuse() {
    super.prepareForReuse()
    titleLabel.text = nil
    teaserLabel.text = nil
    authorLabel.text = nil
  }
  
  func setup(){
    titleLabel.numberOfLines = 0
    teaserLabel.numberOfLines = 0
    authorLabel.numberOfLines = 0
    titleLabel.lmdBenton(bold: true)
    teaserLabel.lmdArnhem()
    self.contentView.addSubview(titleLabel)
    self.contentView.addSubview(teaserLabel)
    self.contentView.addSubview(authorLabel)
    self.contentView.addSubview(bookmarkButton)
    bookmarkButton.pinSize(CGSize(width: 26, height: 26))
    bookmarkButton.accessibilityLabel = "Lesezeichen"
    pin(bookmarkButton.centerY, to: titleLabel.centerY, dist: -3)
    pin(bookmarkButton.right, to: self.contentView.right)
    pin(titleLabel.top, to: self.contentView.top, dist: 0.0)
    pin(titleLabel.left, to: self.contentView.left)
    pin(bookmarkButton.left, to: titleLabel.right, dist: 10)
    pin(teaserLabel.left, to: self.contentView.left)
    pin(teaserLabel.right, to: self.contentView.right)
    pin(teaserLabel.top, to: titleLabel.bottom)
    pin(authorLabel.top, to: teaserLabel.bottom)
    
    pin(authorLabel.left, to: self.contentView.left)
    pin(authorLabel.right, to: self.contentView.right)
    pin(authorLabel.bottom, to: self.contentView.bottom, dist: -1.0)
    
    if let sv = self.contentView.superview {
      pin(self.contentView, to: sv)
    }
    bookmarkButton.onTapping {[weak self] _ in
      Usage.track(Usage.event.drawer.action_tap.Bookmark)
      self?.article?.hasBookmark.toggle()
    }
    Notification.receive(Const.NotificationNames.bookmarkChanged) { [weak self] msg in
      guard let art = msg.sender as? StoredArticle,
            let articleIdentifier = self?.articleIdentifier,
            !articleIdentifier.isEmpty,
            art.html?.name == articleIdentifier else { return }
      self?.bookmarkButton.image = art.hasBookmark ? self?.starFill : self?.star
    }
    registerForStyleUpdates()
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
}

extension LMdPageArticleCell: UIStyleChangeDelegate{
  public func applyStyles() {
    titleLabel.textColor = Const.SetColor.taz2(.text).color
    teaserLabel.textColor = Const.SetColor.taz2(.text).color
    authorLabel.textColor = Const.SetColor.taz2(.text).color
  }
}

extension String {
  func attributed(lineHeightMultiple: CGFloat?) -> NSAttributedString? {
    var attributes:[NSAttributedString.Key : Any] = [:]
    
    if let lineHeightMultiple = lineHeightMultiple, lineHeightMultiple > 0.1 {
      let style = NSMutableParagraphStyle()
      style.lineHeightMultiple = lineHeightMultiple
      attributes[NSAttributedString.Key.paragraphStyle] = style
    }
    return NSAttributedString(string: self,
                              attributes: attributes)
  }
}
