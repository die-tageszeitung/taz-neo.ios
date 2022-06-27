
/**
 CarouselVC:
 A demonstration of the IssueCarousel class which is a CollectionView acting 
 like a carousel while showing Issue images.
*/ 

import UIKit
import NorthLib


class CarouselVC: UIViewController {
  var issueCarousel = IssueCarousel()
  var images: [UIImage] = []
  var isInitialized: Bool = false
  
  override func viewDidLoad() {
    view.backgroundColor = .black
    view.addSubview(issueCarousel)
    pin(issueCarousel, to: view)
    issueCarousel.carousel.scrollFromLeftToRight = true
    issueCarousel.carousel.onDisplay { (idx, view) in 
      if !self.isInitialized {
        self.isInitialized = true
        self.issueCarousel.showAnimations()
      }
      self.debug("display: \(idx)")
    }
    issueCarousel.onTap { idx in 
      let isActive = self.issueCarousel.getActivity(idx: idx)
      self.issueCarousel.setActivity(idx: idx, isActivity: !isActive)
    }
    images = [1,2,3,4,5,6].map { UIImage(named:"Moment 0\($0)")! }
    issueCarousel.addMenuItem(title: "Bild Teilen", icon: "share") { arg in
      self.debug("teilen")
    }
    issueCarousel.addMenuItem(title: "Ausgabe löschen", icon: "trash") { arg in
      self.debug("löschen")
    }
    issueCarousel.addMenuItem(title: "Kontakt", icon: "envelope") { arg in
      self.debug("Kontakt")
    }
    issueCarousel.appendIssues(images)
    issueCarousel.index = 0
  }
  
}
