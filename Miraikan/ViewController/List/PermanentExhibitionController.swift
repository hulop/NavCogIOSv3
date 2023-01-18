//
//  PermanentExhibitionController.swift
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
 Categories of Regular Exhibition
 */
class PermanentExhibitionController: BaseListController, BaseListDelegate {
    
    private let linkId = "linkCell"
    private let descId = "descCell"
    
    override func initTable() {
        // init the tableView
        super.initTable()
        
        self.baseDelegate = self
        self.tableView.register(LinkRow.self, forCellReuseIdentifier: linkId)
        self.tableView.register(DescriptionRow.self, forCellReuseIdentifier: descId)
        
        setSection()
        setHeaderFooter()
    }

    private func setSection() {
        // Load the data
        guard let models = MiraikanUtil.readJSONFile(filename: "exhibition_category",
                                                  type: [RegularExhibitionModel].self)
            as? [RegularExhibitionModel]
        else { return }
        
        let sorted = models.sorted(by: { (a, b) in
            let floorA = a.floor ?? 0
            let floorB = b.floor ?? 0
            return floorA > floorB
        })
        var dividedItems = [Any]()
        
        if NSLocalizedString("lang", comment: "") == "ja" {
            sorted.forEach({ model in
                dividedItems += [model]
                dividedItems += [model.intro]
            })
        } else {
            sorted.forEach({ model in
                dividedItems += [model]
                dividedItems += [model.introEn]
            })
        }

        items = dividedItems
    }

    private func setHeaderFooter() {
        let headerView = UIView (frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: CGFloat.leastNonzeroMagnitude))
        self.tableView.tableHeaderView = headerView
    }

    // MARK: BaseListDelegate
    func getCell(_ tableView: UITableView, _ indexPath: IndexPath) -> UITableViewCell? {
        let item = (items as? [Any])?[indexPath.row]
        if let model = item as? RegularExhibitionModel,
           let cell = tableView.dequeueReusableCell(withIdentifier: linkId,
                                                    for: indexPath)
            as? LinkRow {
            
            var title = model.title
            if NSLocalizedString("lang", comment: "") != "ja" {
                title = model.titleEn
            }
            
            if let floor = model.floor {
                title = String(format: NSLocalizedString("FloorD", tableName: "BlindView", comment: "floor"), String(floor)) + " " + title
            }
            cell.configure(title: title, accessibility: title)
            return cell
        } else if let title = item as? String,
                  let cell = tableView.dequeueReusableCell(withIdentifier: descId,
                                                                 for: indexPath)
                    as? DescriptionRow {
            cell.configure(title: title)
            return cell
        }
        return nil
    }

    override func onSelect(_ tableView: UITableView, _ indexPath: IndexPath) {
        // Only the link is clickable
        if let model = (items as? [Any])?[indexPath.row] as? RegularExhibitionModel {
            guard let nav = self.navigationController as? BaseNavController else { return }
            let vc = MiraikanUtil.routeMode == .blind
                ? BlindExhibitionController(id: model.id, title: model.title)
                : ExhibitionListController(id: model.id, title: model.title)
            nav.show(vc, sender: nil)
        }
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if (indexPath.row / 2 % 2 == 0) {
            cell.backgroundColor = .systemBackground
        } else {
            cell.backgroundColor = .secondarySystemBackground
        }
    }
}
