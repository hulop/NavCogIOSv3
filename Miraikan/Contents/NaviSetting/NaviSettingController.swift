//
//
//  NaviSettingController.swift
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

class NaviSettingController : BaseListController, BaseListDelegate {
    
    private let routeModeId = "routeModeCell"
    private let labelId = "labelCell"
    private let switchId = "switchCell"
    private let sliderId = "sliderCell"
    private let buttonId = "buttonCell"
    
    private struct CellModel {
        let cellId : String
        let model : Any?
    }
    
    override func initTable() {
        super.initTable()
        
        AudioGuideManager.shared.isDisplayButton(false)

        self.baseDelegate = self
        self.tableView.register(RouteModeRow.self, forCellReuseIdentifier: routeModeId)
        self.tableView.register(LabelCell.self, forCellReuseIdentifier: labelId)
        self.tableView.register(SwitchCell.self, forCellReuseIdentifier: switchId)
        self.tableView.register(SliderCell.self, forCellReuseIdentifier: sliderId)
        self.tableView.register(ButtonCell.self, forCellReuseIdentifier: buttonId)
        self.tableView.separatorStyle = .singleLine

        var cellList: [CellModel] = []

        cellList.append(CellModel(cellId: routeModeId, model: nil))
        cellList.append(CellModel(cellId: switchId,
                model: SwitchModel(desc: NSLocalizedString("Voice Guide", comment: ""),
                                   key: "isVoiceGuideOn",
                                   isOn: UserDefaults.standard.bool(forKey: "isVoiceGuideOn"),
                                   isEnabled: nil)))
        cellList.append(CellModel(cellId: sliderId,
                                  model: SliderModel(min: 0.1,
                                                     max: 1,
                                                     defaultValue: MiraikanUtil.speechSpeed,
                                                     step: 0.05,
                                                     format: "%.2f",
                                                     title: NSLocalizedString("Speech Speed", comment: ""),
                                                     name: "speech_speed",
                                                     desc: NSLocalizedString("Speech Speed Description",
                                                                             comment: "Description for VoiceOver"))))
        
        if MiraikanUtil.isLoggedIn {
            cellList.append(CellModel(cellId: buttonId,
                                      model: ButtonModel(title: NSLocalizedString("Logout", comment: ""),
                                                         key: "LoggedIn",
                                                         isEnabled: MiraikanUtil.isLoggedIn,
                                                         tapAction: { [weak self] in
                                                            guard let self = self else { return }
                                                            self.navigationController?.popViewController(animated: true)
            })))
        }
        var locationStr: String
        if MiraikanUtil.isLocated,
           let loc = MiraikanUtil.location {
            locationStr = " \(loc.lat)\n \(loc.lng)\n \(loc.floor)F\n speed: \(loc.speed)\n accuracy: \(loc.accuracy)\n orientation: \(loc.orientation)\n orientationAccuracy: \(loc.orientationAccuracy)"
        } else {
            locationStr = NSLocalizedString("not_located", comment: "")
        }
        cellList.append(CellModel(cellId: labelId,
                                  model: LabelModel(title: NSLocalizedString("Current Location", comment: ""),
                                                    value: locationStr
                                                   )))

        cellList.append(CellModel(cellId: switchId,
               model: SwitchModel(desc: NSLocalizedString("Preview", comment: ""),
                                  key: "OnPreview",
                                  isOn: MiraikanUtil.isPreview,
                                  isEnabled: nil)))
        cellList.append(CellModel(cellId: sliderId,
                                  model: SliderModel(min: 1,
                                                     max: 10,
                                                     defaultValue: MiraikanUtil.previewSpeed,
                                                     step: 1,
                                                     format: "%d",
                                                     title: NSLocalizedString("Preview Speed", comment: ""),
                                                     name: "preview_speed",
                                                     desc: NSLocalizedString("Preview Speed Description",
                                                                             comment: "Description for VoiceOver"))))

        cellList.append(CellModel(cellId: switchId,
                                  model: SwitchModel(desc: NSLocalizedString("Move Log", comment: ""),
                                                     key: "DebugMode",
                                                     isOn: UserDefaults.standard.bool(forKey: "DebugMode"),
                                                     isEnabled: nil)))

        self.items = cellList
    }
    
    func getCell(_ tableView: UITableView, _ indexPath: IndexPath) -> UITableViewCell? {
        let item = (items as? [CellModel])?[indexPath.row]
        guard let cellId = item?.cellId else { return nil }
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath)
        
        if let cell = cell as? RouteModeRow {
            return cell
        } else if let cell = cell as? LabelCell, let model = item?.model as? LabelModel {
            cell.configure(model)
            return cell
        } else if let cell = cell as? SwitchCell, let model = item?.model as? SwitchModel {
            cell.configure(model)
            return cell
        } else if let cell = cell as? SliderCell,
                    let model = item?.model as? SliderModel {
            cell.configure(model)
            return cell
        } else if let cell = cell as? ButtonCell,
                    let model = item?.model as? ButtonModel {
            cell.configure(model)
            return cell
        }
        
        return nil
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        super.tableView(tableView, didSelectRowAt: indexPath)
        let item = (items as? [CellModel])?[indexPath.row]
        guard let cellId = item?.cellId else { return }
        if cellId == labelId {
            if let nav = self.navigationController {
                nav.show(DistanceCheckViewController(title: ""), sender: nil)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return UIView()
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
}
