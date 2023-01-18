//
//
//  BaseListController.swift
//  NavCogMiraikan
//
/*******************************************************************************
 * Copyright (c) 2021 © Miraikan - The National Museum of Emerging Science and Innovation  
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/

import Foundation
import UIKit

/**
 The interface for UITableViewController usages
 */
protocol BaseListDelegate {
    func getCell(_ tableView: UITableView,
                 _ indexPath: IndexPath) -> UITableViewCell?
}

/**
 The parent UITableViewController to be inherited by specific lists
 */
class BaseListController: UITableViewController {

    public var baseDelegate: BaseListDelegate?

    public var items: Any? {
        didSet {
            self.tableView.reloadData()
        }
    }

    // MARK: init
    init(title: String?) {
        super.init(style: .grouped)
        self.title = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setup()
        initTable()
    }

    func initTable() {
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.separatorStyle = .none
        self.tableView.backgroundColor = .systemBackground

        if #available(iOS 15, *) {
            tableView.sectionHeaderTopPadding = 0.0
        }
    }

    func setup() {
        // NavBar
        let btnSetting = BaseBarButton(image: UIImage(named: "icons8-setting"))
        btnSetting.tapAction { [weak self] in
            guard let self = self else { return }
            let vc = NaviSettingController(title: NSLocalizedString("Navi Settings", comment: ""))
            self.navigationController?.show(vc, sender: nil)
        }
        self.navigationItem.rightBarButtonItem = btnSetting
    }

    // MARK: UITableViewDelegate
    override func numberOfSections(in tableView: UITableView) -> Int {
        if let _ = items as? [Any] {
            return 1
        } else if let items = items as? [Int: Any] {
            return items.count
        }
        
        return 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let items = items as? [Any] {
            return items.count
        } else if let items = items as? [Int: [Any]] {
            return items[section]?.count ?? 0
        }
            
        return 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = baseDelegate?.getCell(tableView, indexPath) {
            return cell
        }
        return UITableViewCell()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.onSelect(tableView, indexPath)
    }

    // MARK: BaseListDelegate
    func onSelect(_ tableView: UITableView, _ indexPath: IndexPath) {
        print("Selected item at: \(indexPath.section), \(indexPath.row)")
        tableView.deselectRow(at: indexPath, animated: true)
        
    }
}
