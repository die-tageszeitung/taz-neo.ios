
/**
 CarouselTest:
 A demonstration of the CarouselView class which is a CollectionView acting like a carousel
*/ 

import UIKit
import NorthLib

/// A simple view to populate Carousel
class TestView: UIView, Touchable {
  var label = UILabel()
  var recognizer = TapRecognizer()
  
  init(frame: CGRect, n: Int) {
    super.init(frame: frame)
    label.text = "\(n)"
    let col: UIColor = [.red, .green, .yellow][n%3]
    backgroundColor = col
    addSubview(label)
    pin(label.centerX, to: self.centerX)
    pin(label.centerY, to: self.centerY)
    isUserInteractionEnabled = true
    onTap {_ in self.debug(self.label.text) }
  }
  
  required init?(coder: NSCoder) { super.init(coder: coder) }
}

/// Main view controller with a logView
class ViewController: UIViewController {
  var viewLogger = Log.ViewLogger()
  var carousel = CarouselView()
  
  override func loadView() {
    let view = UIView()
    view.backgroundColor = .white
    view.addSubview(viewLogger.logView)
    viewLogger.logView.pinToView(view)
    Log.append(logger: viewLogger)
    Log.minLogLevel = .Debug
    viewLogger.logView.onTap {_ in
      self.carousel.isHidden = !self.carousel.isHidden
    }
    view.addSubview(carousel)
    pin(carousel.left, to: view.left)
    pin(carousel.right, to: view.right)
    pin(carousel.centerY, to: view.centerY)
    carousel.pinHeight(400)
    carousel.backgroundColor = .lightGray
    carousel.scrollFromLeftToRight = true
    carousel.viewProvider { (i, oview) in
      let tv = TestView(frame: CGRect(), n: i+1)
      tv.pinHeight(300)
      return tv
    }
    carousel.onDisplay { idx in 
      if (idx != 0) && ((idx % 7) == 0) { self.carousel.count += 10 }
    }
    self.view = view
  }
  
  override func viewDidAppear(_ animated: Bool) {
    self.carousel.count = 10
    self.carousel.index = 0
  }
}

class IssueTestVC: UIViewController {
  var issueCarousel = IssueCarousel()
  var images: [UIImage] = []
  
  override func loadView() {
    let view = UIView()
    view.backgroundColor = .black
    let consoleLogger = Log.Logger()
    Log.append(logger: consoleLogger)
    Log.minLogLevel = .Debug
    view.addSubview(issueCarousel)
    pin(issueCarousel, to: view)
    issueCarousel.scrollFromLeftToRight = true
    issueCarousel.relativePageWidth = 0.6
    issueCarousel.relativeSpacing = 0.12
    issueCarousel.onDisplay { idx in 
      self.debug("display: \(idx)")
    }
    issueCarousel.onPress { idx in 
      self.debug("tap: \(idx)")
    }
    self.view = view
  }
  
  override func viewDidAppear(_ animated: Bool) {
    images = [1,2,3,4,5,6].map { UIImage(named:"Moment 0\($0)")! }
    issueCarousel.appendIssues(images)
  }
}
