//
//  FakeTableTableViewController.swift
//  taz.neo
//
//  Created by Ringo Müller on 02.05.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

import UIKit

class FakeTableTableViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

    }


   

}

class FakeTableView: UITableView {
  private func setup() {
    self.register(UITableViewCell.self, forCellReuseIdentifier: "reuseIdentifier")
//    self.delegate = self
    self.dataSource = self
  }
  
  override init(frame: CGRect, style: UITableView.Style) {
    super.init(frame: frame, style: style)
    setup()
  }
  
  public required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
}


extension FakeTableView : UITableViewDataSource {
  // MARK: - Table view data source

  func numberOfSections(in tableView: UITableView) -> Int {
      return 1
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
      return 100
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
      let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)
    cell.textLabel?.text = "Zelle: \(indexPath.row)"
    return cell
  }

}
