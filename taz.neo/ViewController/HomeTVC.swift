//
//  HomeTVC.swift
//  taz.neo
//
//  Created by Ringo Müller on 01.02.23.
//  Copyright © 2023 Norbert Thies. All rights reserved.
//

import UIKit
import NorthLib

class HomeTVC: UITableViewController {
  
  //  var service: DataService
  
  /**
   Selection unten => Top Ausgabe ist selectiert
   
   same Index
   ==> besser: ich bin 1.1.2005 oben scrolle runter und bin dort auch P*A*R*T*Y
   ==> kann SOMIT besser die richtige Ausgabe finden und muss nicht ewig scrollen
   ==> DO IT!!
   BETTER 2 STEP NAVIGATION
   unten 5.5.2015 HOME => Scroll Tiles newest => HOME GOTO TOP
   
   */
  
  var carouselController: IssueCarouselCVC
  var tilesController: IssueCarouselCVC
  
  var carouselControllerCell: UITableViewCell
  var tilesControllerCell: UITableViewCell
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = .black
  }
  
  // MARK: - Table view data source
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    // #warning Incomplete implementation, return the number of sections
    return 1
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    // #warning Incomplete implementation, return the number of rows
    return 2
  }
  
  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return self.view.frame.size.height
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    return indexPath.row == 0 ? carouselControllerCell : tilesControllerCell
  }
  
  
  public init(service: DataService) {
    //    self.service = service
    carouselController = IssueCarouselCVC(service: service)
    tilesController = IssueCarouselCVC(service: service)
    
    carouselControllerCell = UITableViewCell()
    tilesControllerCell = UITableViewCell()
    
    super.init(style: .plain)
    
    self.addChild(carouselController)
    self.addChild(tilesController)
    
    carouselControllerCell.contentView.addSubview(carouselController.view)
    pin(carouselController.view, to: carouselControllerCell)
    
    tilesControllerCell.contentView.addSubview(tilesController.view)
    pin(tilesController.view, to: tilesControllerCell)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

// MARK: - UIScrollViewDelegate
extension HomeTVC {
  open override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    snapCell()
  }
  
  open override func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
    snapCell()
  }
  
  func snapCell() {
    let up = self.view.frame.size.height/2 > self.tableView.contentOffset.y
    let ip = IndexPath(row: up ? 0 : 1, section: 0)
    self.tableView.scrollToRow(at: ip, at: .top, animated: true)
  }
}
