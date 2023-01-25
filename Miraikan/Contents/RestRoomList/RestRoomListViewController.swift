//
//
//  RestRoomListViewController.swift
//  NavCogMiraikan
//
/*******************************************************************************
 * Copyright (c) 2022 © Miraikan - The National Museum of Emerging Science and Innovation  
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


class RestRoomListViewController: BaseListController, BaseListDelegate {

    private let cellId = "RestRoomCell"
    var restList: [HLPSectionModel] = []

    override func initTable() {
        // init the tableView
        super.initTable()

        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0.0
        }

        self.baseDelegate = self
        self.tableView.allowsSelection = true

        setSection()
    }

    private func setSection() {
        restList = AudioGuideManager.shared.getRestList()
        var restTitles: [String] = []

        var restItems: [HLPSectionModel] = []
        for item in restList {
            if !restTitles.contains(item.title) {
                restTitles.append(item.title)
                restItems.append(item)
            }
        }
        
        restItems.sort(by: { $0.title.compare($1.title) == ComparisonResult.orderedAscending })
        items = restItems
    }

    // MARK: BaseListDelegate
    func getCell(_ tableView: UITableView, _ indexPath: IndexPath) -> UITableViewCell? {
        let cell = UITableViewCell(style: .default, reuseIdentifier: cellId)
        
        if let items = items as? [HLPSectionModel],
           indexPath.row < items.count {
            NSLog("\(items[indexPath.row].title)")
            if #available(iOS 14.0, *) {
                var content = cell.defaultContentConfiguration()
                content.text = items[indexPath.row].title
                cell.contentConfiguration = content
            } else {
                cell.textLabel?.text = items[indexPath.row].title
            }
        }
        return cell
    }

    // MARK: UITableView
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if (indexPath.row % 2 == 0) {
            cell.backgroundColor = .tertiarySystemGroupedBackground
        } else {
            cell.backgroundColor = .secondarySystemGroupedBackground
        }
    }

    override func onSelect(_ tableView: UITableView, _ indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        var list: [HLPSectionModel] = []
        if let items = items as? [HLPSectionModel],
           indexPath.row < items.count {
            let title = items[indexPath.row].title
            for item in restList {
                if item.toilet == items[indexPath.row].toilet,
                    !item.title.isEmpty,
                   item.title.contains(title) {
                    list.append(item)
                }
            }
        }
        
        if let navDataStore = NavDataStore.shared(),
           let currentLocation = navDataStore.currentLocation(),
           !currentLocation.lat.isNaN,
           !currentLocation.lng.isNaN {
            let currentFloor = Int(currentLocation.floor)
            
            let isExhibitionZone = AudioGuideManager.shared.isExhibitionZone(current: currentLocation)
            let floor = Int(currentFloor < 0 ? currentLocation.floor : currentLocation.floor + 1)
            
            let TopFloor = 7
            let BottomFloor = -2
            let MiddleFloor = 4
            let FloorCount = 10

            var floorList: [Int] = []
            let isAscending = floor > MiddleFloor
            for i in 0 ..< FloorCount {
                var checkFloor = floor + (isAscending ? -1 : 1) * i
                if checkFloor > TopFloor { checkFloor -= -FloorCount }
                if checkFloor < BottomFloor { checkFloor += FloorCount }
                floorList.append(checkFloor)
            }

            var item = checkFloor(floorList: floorList, list: list, isExhibitionZone: isExhibitionZone)
            if item == nil {
                item = checkFloor(floorList: floorList, list: list, isExhibitionZone: !isExhibitionZone)
            }

            if let item = item {
                guard let nav = self.navigationController as? BaseNavController else { return }
                nav.openMap(nodeId: item.nodeId)
                return
            }
        } else {
            let alert = UIAlertController(title: nil, message: NSLocalizedString("location unknown", comment: ""), preferredStyle: .alert)
            let yesAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default)
            alert.addAction(yesAction)
            present(alert, animated: true, completion: nil)

        }
    }

    func checkFloor(floorList: [Int], list: [HLPSectionModel], isExhibitionZone: Bool) -> HLPSectionModel? {
        for checkFloor in floorList {
            for item in list {
                if let itemFloor = item.floor,
                   itemFloor == checkFloor,
                   item.isExhibitionZone == isExhibitionZone {
                    return item
                }
            }
        }
        return nil
    }
}
