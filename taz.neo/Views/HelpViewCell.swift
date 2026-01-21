import UIKit
import NorthLib

final class HelpViewCell: UIView {
  
  // MARK: - Public API
  var targetView: UIView?
  var contentView: UIView?
  
  var item: HelpItem? {
    didSet {
      configure()}
  }
  
  private let titleLabel = UILabel()
  private let subLabel = UILabel()
  
  private var topImageView: UIImageView?
  
  lazy var textLayer: UIView = {
    let wrapper = UIView()
    titleLabel.americanTypewriter(size: 32).white().centerText()
    subLabel.contentFont().white().centerText()
    titleLabel.numberOfLines = 0
    titleLabel.lineBreakMode = .byWordWrapping
    subLabel.numberOfLines = 0
    wrapper.addSubview(titleLabel)
    wrapper.addSubview(subLabel)
    pin(titleLabel, to: wrapper, exclude: .bottom)
    pin(subLabel, to: wrapper, exclude: .top)
    pin(subLabel.top, to: titleLabel.bottom, dist: 5.0)
    return wrapper
  }()
  
  private var textWidthConstraint: NSLayoutConstraint?
  private var yContraint: NSLayoutConstraint?
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  // MARK: - Setup
  
  private func setup() {
    addSubview(textLayer)
    textLayer.centerX()
    yContraint = textLayer.centerY(dist: HelpView.cellYoffset)
    textLayer.transform = CGAffineTransform(rotationAngle: -8 * .pi/180)
    textWidthConstraint = textLayer.pinWidth(UIWindow.size.width * 0.7)
    titleLabel.isAccessibilityElement = true
    subLabel.isAccessibilityElement = true
  }
  
  // MARK: - Configure / Reset
  
  func configure() {
    topImageView?.removeFromSuperview()
    topImageView = nil
    yContraint?.constant = HelpView.cellYoffset
    
    contentView?.removeFromSuperview()
    self.targetView = item?.targetView
    
    if let title = item?.title, #available(iOS 15.0, *) {
      let p = NSMutableParagraphStyle()
      p.hyphenationFactor = 1.0
      p.lineBreakMode = .byWordWrapping
      p.alignment = .center
      titleLabel.attributedText = NSAttributedString(
        string: title,
        attributes: [
          .paragraphStyle: p,
          .languageIdentifier: "de"
        ]
      )
    }
    else {
      titleLabel.text = item?.title
    }
    subLabel.text = item?.text

    if let cv = item?.contentView,
       (item?.text.isEmpty ?? true) == true {
      /// ONLY Content View - no Text
      contentView = cv
      contentView?.isAccessibilityElement = false
//      cv.transform = CGAffineTransform(rotationAngle: -8 * .pi/180)
      addSubview(cv)
      pin(cv.top, to: titleLabel.bottom, dist: 22)
      pin(cv.left, to: self.left)
      pin(cv.right, to: self.right)
      pin(cv.bottom, to: textLayer.bottom)
    }
    else  if let cv = item?.contentView {
      contentView = cv
      contentView?.isAccessibilityElement = false
//      cv.transform = CGAffineTransform(rotationAngle: -8 * .pi/180)
      addSubview(cv)
      pin(cv.top, to: subLabel.bottom, dist: 22)
      pin(cv.left, to: self.left)
      pin(cv.right, to: self.right)
      pin(cv.bottom, to: textLayer.bottom)
    }
    
    if let iv = item?.topImageView {
      topImageView = iv
      topImageView?.isAccessibilityElement = false
      iv.transform = CGAffineTransform(rotationAngle: -8 * .pi/180)
      addSubview(iv)
      iv.centerX(dist: -10)
      pin(iv.bottom, to: textLayer.top, dist: -12)
      yContraint?.constant = HelpView.cellYoffset + (iv.frame.height / 2)
    }
  }
  
  func reset() {
    targetView = nil
    item?.contentView?.removeFromSuperview()
    item = nil
    titleLabel.text = nil
    subLabel.text = nil
  }
}

extension CGRect {
  var center: CGPoint {
    return CGPoint(x: origin.x + width/2, y: origin.y + height/2)
  }
}
