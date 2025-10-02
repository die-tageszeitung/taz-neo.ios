import UIKit
import NorthLib

final class CoachmarkView: UIView {
  
  // MARK: - Public API
  
  private(set) var closeClosure: (() -> Void)?
  func onClose(closure: @escaping () -> Void) {
    closeClosure = closure
  }
  
  var targetView: UIView?
  var contentView: UIView?
  var alternativeTarget: (UIImage, [UIView], [CGPoint])?
  
  var item: HelpItem? {
    didSet {
      configure()}
  }
  
  private let titleLabel = UILabel()
  private let subLabel = UILabel()
  
  lazy var textLayer: UIView = {
    let wrapper = UIView()
    titleLabel.americanTypewriter(size: 32).white().centerText()
    subLabel.contentFont().white().centerText()
    titleLabel.numberOfLines = 0
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
  private var alternativeTargetImageViews: [UIImageView] = []
  
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
    //        addSubview(background)
    //        pin(background, to: self)
    //        background.layer.mask = maskLayer
    //        background.backgroundColor = .black.withAlphaComponent(0.8)
    
    
    
    addSubview(textLayer)
    textLayer.centerAxis()
    textLayer.transform = CGAffineTransform(rotationAngle: -8 * .pi/180)
    textWidthConstraint = textLayer.pinWidth(UIWindow.size.width * 0.7)
    
    textLayer.onTapping { [weak self] _ in self?.closeClosure?() }
    //        background.onTapping { [weak self] _ in self?.closeClosure?() }
  }
  
  // MARK: - Configure / Reset
  
  func configure() {
    contentView?.removeFromSuperview()
    self.targetView = item?.targetView
    //        self.alternativeTarget = alternativeTarget
    
    titleLabel.text = item?.title
    subLabel.text = item?.text
    
    if let cv = item?.contentView,
       (item?.text.isEmpty ?? true) == true {
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
    
    // Reset alternativeTargetViews
    alternativeTargetImageViews.forEach { $0.removeFromSuperview() }
    alternativeTargetImageViews.removeAll()
    
    if let at = alternativeTarget {
      for _ in 0..<at.1.count {
        let iv = UIImageView(image: at.0)
        iv.contentMode = .scaleAspectFit
        addSubview(iv)
        alternativeTargetImageViews.append(iv)
      }
    }
  }
  
  func reset() {
    closeClosure = nil
    targetView = nil
    alternativeTarget = nil
    item?.contentView?.removeFromSuperview()
    item = nil
    titleLabel.text = nil
    subLabel.text = nil
    alternativeTargetImageViews.forEach { $0.removeFromSuperview() }
    alternativeTargetImageViews.removeAll()
  }
}

extension CGRect {
  var center: CGPoint {
    return CGPoint(x: origin.x + width/2, y: origin.y + height/2)
  }
}
