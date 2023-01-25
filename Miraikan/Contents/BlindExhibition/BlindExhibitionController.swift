//
//  BlindExhibitionController.swift
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
 The list for Regular Exhibitions
 
 - Parameters:
 - id: category id
 - title: The title for NavigationBar
 */
class BlindExhibitionController: BaseListController, BaseListDelegate {
    
    private let category: String
    
    private let navId = "navCell"
    private let contentId = "descCell"
    
    private let cells : [String]!
    private var headers = [ExhibitionLinkModel]()
    
    // MARK: init
    init(id: String, title: String) {
        self.category = id
        self.cells = [navId, contentId]
        super.init(title: title)
        self.baseDelegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func initTable() {
        // init the tableView
        super.initTable()
        
        self.tableView.register(NavButtonRow.self, forCellReuseIdentifier: navId)
        self.tableView.register(ContentRow.self, forCellReuseIdentifier: contentId)
        
        // Load the data
        guard let models = MiraikanUtil.readJSONFile(filename: "exhibition",
                                                  type: [ExhibitionModel].self)
            as? [ExhibitionModel]
        else { return }
        let sorted = models
            .filter({ model in
                if category == "world" {
                    return model.category == category || model.category == "calendar"
                }
                return model.category == category
            })
            .sorted(by: { $0.counter < $1.counter })
        var sections = [(NavButtonModel, ExhibitionContentModel)]()
        sorted.forEach({ model in
            var hlpLocation: HLPLocation?
            if let latitudeStr = model.latitude,
               let longitudeStr = model.longitude,
               let latitude = Double(latitudeStr),
               let longitude = Double(longitudeStr) {
                hlpLocation = HLPLocation(lat: latitude, lng: longitude)
            }

            let linkModel = ExhibitionLinkModel(id: model.id,
                                                title: model.title,
                                                titlePron: model.titlePron,
                                                hlpLocation: hlpLocation,
                                                category: model.category,
                                                nodeId: model.nodeId,
                                                counter: model.counter,
                                                locations: model.locations,
                                                blindDetail: model.blindDetail)
            headers += [linkModel]
            let navModel = NavButtonModel(nodeId: model.nodeId,
                                          locations: model.locations,
                                          title: model.title,
                                          titlePron: model.titlePron)
            let contentModel = ExhibitionContentModel(title: model.title,
                                                      intro: model.intro,
                                                      blindIntro: model.blindIntro,
                                                      blindOverview: model.blindOverview)
            sections += [(navModel, contentModel)]
        })
        items = sections

        setFooter()
    }

    private func setFooter() {
        let footerView = UIView (frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: 80.0))
        self.tableView.tableFooterView = footerView
    }

    // MARK: BaseListDelegate
    func getCell(_ tableView: UITableView, _ indexPath: IndexPath) -> UITableViewCell? {
        let item = (items as? [(NavButtonModel, ExhibitionContentModel)])?[indexPath.section]
        let cellId = cells[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath)
        
        if let model = item?.0, let cell = cell as? NavButtonRow {
            if let nodeId = model.nodeId {
                cell.configure(nodeId: nodeId, title: model.titlePron)
            } else if let locations = model.locations, let title = model.title {
                cell.configure(locations: locations, title: title)
            }
            return cell
        } else if let model = item?.1,
                  let cell = cell as? ContentRow {
            cell.configure(model)
            return cell
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = LinkingHeader()
        header.model = headers[section]
        header.isFirst = section == 0
        return header
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        guard let sections = items as? [Any] else { return 0 }
        return sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let items = items as? [(Any, Any)] else { return 0 }
        return Mirror(reflecting: items[section]).children.count
    }
}
