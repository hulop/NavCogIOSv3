//
//
//  BaseListView.swift
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
 The parent UIView which contains a UITableView.
 This is to be inherited by those screens implemented as UIView and difficult to rewrite as UIViewController
 */
class BaseListView: BaseView, UITableViewDelegate, UITableViewDataSource {

    let tableView = UITableView()

    public var items: Any? {
        didSet {
            self.tableView.reloadData()
        }
    }

    // MARK: init
    override func setup() {
        super.setup()
        
        initTable(isSelectionAllowed: false)
        addSubview(tableView)
    }

    func initTable(isSelectionAllowed: Bool) {
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.allowsSelection = isSelectionAllowed
        self.tableView.separatorStyle = .none
        self.tableView.backgroundColor = .systemBackground

        if #available(iOS 15, *) {
            tableView.sectionHeaderTopPadding = 0.0
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        tableView.frame = self.frame
    }

    // MARK: UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        if let _ = items as? [Any] {
            return 1
        } else if let items = items as? [Int: [Any]] {
            return items.count
        }
        
        return 0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let items = items as? [Any] {
            return items.count
        } else if let items = items as? [Int: [Any]] {
            return items[section]?.count ?? 0
        }
        
        return 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }

    // MARK: UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
}
