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
  
  var teaserLabelTopConstraint: NSLayoutConstraint?
  var authorLabelTopConstraint: NSLayoutConstraint?
  
  /// Helper to prevent Simultaneous accesses to article, but modification requires exclusive access.
  /// on bookmarking and receive notification
  var articleIdentifier: String?
  
  var article: Article? {
    didSet {
      titleLabel.text = article?.title
      teaserLabel.text = article?.teaser
      ///authors & readingDuration
      var autors = article?.authors() ?? ""
      if autors.length > 0 {
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
      authorLabel.text = ""
      authorLabel.lmdArnhem(italic: true)
      authorLabel.textColor = .black
      authorLabel.attributedText = attributedString
      
      teaserLabelTopConstraint?.constant
      = teaserLabel.text?.isEmpty ?? true ? 0 : 7
      authorLabelTopConstraint?.constant
      = authorLabel.text?.isEmpty ?? true ? 0 : 12
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
    titleLabel.lmdBenton(bold: true, size: 14.0)
    teaserLabel.lmdArnhem()
    self.contentView.addSubview(titleLabel)
    self.contentView.addSubview(teaserLabel)
    self.contentView.addSubview(authorLabel)
    self.contentView.addSubview(bookmarkButton)
    bookmarkButton.pinSize(CGSize(width: 26, height: 26))
    bookmarkButton.accessibilityLabel = "Lesezeichen"
    pin(bookmarkButton.centerY, to: titleLabel.centerY, dist: -3)
    pin(bookmarkButton.right, to: self.contentView.right)
    pin(titleLabel.top, to: self.contentView.top)
    pin(titleLabel.left, to: self.contentView.left)
    pin(bookmarkButton.left, to: titleLabel.right, dist: 10)
    pin(teaserLabel.left, to: self.contentView.left)
    pin(teaserLabel.right, to: self.contentView.right)
    teaserLabelTopConstraint = pin(teaserLabel.top, to: titleLabel.bottom)
    authorLabelTopConstraint = pin(authorLabel.top, to: teaserLabel.bottom)
    pin(authorLabel, to: self.contentView, exclude: .top)
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
