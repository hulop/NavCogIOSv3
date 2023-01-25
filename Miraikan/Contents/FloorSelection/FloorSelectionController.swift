//
//  FloorSelectionController.swift
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
 The screen for floor selection before navigation is starting.
 The location for each floor has its own nodeId (destination id).
 */
class FloorSelectionController: BaseListController, BaseListDelegate {

    private let cellId = "floorCell"

    override func initTable() {
        super.initTable()

        self.baseDelegate = self
        self.tableView.separatorStyle = .singleLine
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellId)
    }

    func getCell(_ tableView: UITableView, _ indexPath: IndexPath) -> UITableViewCell? {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath)
        if let model = (items as? [Any])?[indexPath.row] as? ExhibitionLocation {
            cell.textLabel?.text = String(format: NSLocalizedString("FloorD", tableName: "BlindView", comment: "floor"), String(model.floor))
        }
        return cell
    }

    override func onSelect(_ tableView: UITableView, _ indexPath: IndexPath) {
        super.onSelect(tableView, indexPath)

        if let nav = self.navigationController as? BaseNavController,
           let model = (items as? [Any])?[indexPath.row] as? ExhibitionLocation {
            nav.openMap(nodeId: model.nodeId)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
