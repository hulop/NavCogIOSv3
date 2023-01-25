//
//  EventListController.swift
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
 List of Today's schedule
 */
class EventListController: BaseListController, BaseListDelegate {
    
    private let cellId = "eventCell"
    
    override func initTable() {
        // init the tableView
        super.initTable()
        
        self.baseDelegate = self
        self.tableView.allowsSelection = false
        self.tableView.register(ScheduleRow.self, forCellReuseIdentifier: cellId)
        
        setSection()
        setHeaderFooter()
    }

    private func setSection() {
        // load the data
        var models = [ScheduleRowModel]()
        ExhibitionDataStore.shared.schedules?.forEach({ schedule in
            if let floorMaps = MiraikanUtil.readJSONFile(filename: "floor_map",
                                         type: [FloorMapModel].self) as? [FloorMapModel],
               let floorMap = floorMaps.first(where: {$0.id == schedule.place }),
               let event = ExhibitionDataStore.shared.events?.first(where: {$0.id == schedule.event}) {
                let model = ScheduleRowModel(schedule: schedule,
                                             floorMap: floorMap,
                                             event: event)
                models += [model]
            }
        })
        items = models
    }

    private func setHeaderFooter() {
        let footerView = UIView (frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: 80.0))
        self.tableView.tableFooterView = footerView
    }

    // MARK: BaseListDelegate
    func getCell(_ tableView: UITableView, _ indexPath: IndexPath) -> UITableViewCell? {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellId,
                                                       for: indexPath) as? ScheduleRow
        else { return UITableViewCell() }
        
        if let model = (items as? [Any])?[indexPath.row] as? ScheduleRowModel {
            cell.configure(model)
        }
        return cell
    }
    
    // MARK: UITableView
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            return ScheduleListHeader()
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if (indexPath.row % 2 == 0) {
            cell.backgroundColor = .tertiarySystemGroupedBackground
        } else {
            cell.backgroundColor = .secondarySystemGroupedBackground
        }
    }
}
