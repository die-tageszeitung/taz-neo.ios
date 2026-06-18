// A reusable icon+label button that hides its label when 'compressed' is true.
// Use this for toolbar/menu controls where the label should disappear in compact mode.

import UIKit
import NorthLib

class IconLabelButton: UIControl {
  let imageView = UIImageView()
  let label = UILabel()
  
  
  init(image: UIImage?, text: String) {
    super.init(frame: .zero)
    imageView.image = image
    imageView.contentMode = .scaleAspectFill
    imageView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(imageView)
    label.text = text
    label.font =  Const.Fonts.contentFont(size: 11.0)
    label.textAlignment = .center
    label.textColor = .label
    label.translatesAutoresizingMaskIntoConstraints = false
    addSubview(label)
    addBorder(.systemPink)
    label.addBorder(.green)
    imageView.pinSize(CGSize(width: 32.0, height: 32.0))
    
    NSLayoutConstraint.activate([
      imageView.topAnchor.constraint(equalTo: topAnchor),
      imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
      label.leadingAnchor.constraint(equalTo: leadingAnchor),
      label.trailingAnchor.constraint(equalTo: trailingAnchor),
      label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 2.0),
      imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -9)
    ])
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // Convenience to set the icon after init
  func setImage(_ image: UIImage?) {
    imageView.image = image
  }
  // Convenience to set the label after init
  func setText(_ text: String) {
    label.text = text
  }
}
