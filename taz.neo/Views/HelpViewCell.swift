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
    pin(subLabel.top, to: titleLabel.bottom)
    wrapper.accessibilityLabel = "Hinweis – Schliessen durch Tippen"
    return wrapper
  }()
  

  
  private var textWidthConstraint: NSLayoutConstraint?
  
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
    textLayer.centerAxis()
    textLayer.transform = CGAffineTransform(rotationAngle: -8 * .pi/180)
    textWidthConstraint = textLayer.pinWidth(UIWindow.size.width * 0.7)
  }
  
  // MARK: - Configure / Reset
  
  func configure() {
    topImageView?.removeFromSuperview()
    topImageView = nil
    
    contentView?.removeFromSuperview()
    self.targetView = item?.targetView
    
    titleLabel.text = item?.title
    subLabel.text = item?.text

    if let cv = item?.contentView,
       (item?.text.isEmpty ?? true) == true {
      /// ONLY Content View - no Text
      contentView = cv
      cv.transform = CGAffineTransform(rotationAngle: -8 * .pi/180)
      addSubview(cv)
      pin(cv.top, to: titleLabel.bottom, dist: 22)
      pin(cv, to: textLayer, exclude: .top)
    }
    else  if let cv = item?.contentView {
      contentView = cv
      cv.transform = CGAffineTransform(rotationAngle: -8 * .pi/180)
      addSubview(cv)
      pin(cv.top, to: subLabel.bottom, dist: 22)
      pin(cv, to: textLayer, exclude: .top)
    }
    
    if let iv = item?.topImageView {
      topImageView = iv
      iv.transform = CGAffineTransform(rotationAngle: -8 * .pi/180)
      addSubview(iv)
      iv.centerX(dist: -10)
      pin(iv.bottom, to: textLayer.top, dist: -12)
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
