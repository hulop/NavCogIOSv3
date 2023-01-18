//
//  SettingView.swift
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
 Caution: This is related to but not the same as the modes in NavCog3
 */
enum RouteMode : String, CaseIterable {
    case general
    case wheelchair
//    case stroller
    case blind
    
    var description: String {
        switch self {
        case .general:
            return NSLocalizedString("user_general", comment: "")
        case .wheelchair:
            return NSLocalizedString("user_wheelchair", comment: "")
//        case .stroller:
//            return NSLocalizedString("user_stroller", comment: "")
        case .blind:
            return NSLocalizedString("user_blind", comment: "")
        }
    }

    var rawInt: Int {
        switch self {
        case .general:
            return 1
        case .wheelchair:
            return 2
//        case .stroller:
//            return 3
        case .blind:
            return 9
        }
    }
}

fileprivate class RouteModeRow: BaseRow {
    
    private var radioGroup = [RouteMode: RadioButton]()
    
    // Sizing
    private let gapX: CGFloat = 20
    private let gapY: CGFloat = 16

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.selectionStyle = .none
        
        RouteMode.allCases.forEach({ mode in
            let btn = RadioButton()
            btn.setTitle(mode.description, for: .normal)
            btn.setTitleColor(.label, for: .normal)
            btn.titleLabel?.font = .preferredFont(forTextStyle: .callout)
            btn.isChecked = mode == MiraikanUtil.routeMode
            btn.tapAction({ [weak self] _ in
                guard let _self = self else { return }
                if !btn.isChecked {
                    btn.isChecked = true
                    _self.radioGroup.forEach({
                        let (k, v) = ($0.key, $0.value)
                        if k != mode { v.isChecked = false }
                    })
                    UserDefaults.standard.setValue(mode.rawValue, forKey: "RouteMode")
                }
            })
            
            radioGroup[mode] = btn
            addSubview(btn)
        })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        var y = insets.top + gapY
        RouteMode.allCases.forEach({ mode in
            let btn = radioGroup[mode]!
            let szFit = btn.sizeThatFits(innerSize)
            btn.frame = CGRect(x: insets.left + gapX,
                               y: y,
                               width: szFit.width - gapX * 2,
                               height: szFit.height + gapY)
            y += btn.frame.height
        })
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {

        var y = insets.top + gapY
        RouteMode.allCases.forEach({ mode in
            let btn = radioGroup[mode]!
            let szFit = btn.sizeThatFits(innerSize)
            y += szFit.height + gapY
        })
        return CGSize(width: size.width, height: y)
    }
}

// TODO: Display route histories
/**
 Current usage: select navigation mode
 */
class SettingView : BaseListView {
    
    private let routeModeId = "routeModeCell"
    
    override func initTable(isSelectionAllowed: Bool) {
        super.initTable(isSelectionAllowed: isSelectionAllowed)
        
        self.tableView.register(RouteModeRow.self, forCellReuseIdentifier: routeModeId)
        
        items = [routeModeId]
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cellId = (items as? [String])?[indexPath.row] else { return UITableViewCell() }
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath)
        
        if let routeModeCell = cell as? RouteModeRow {
            return routeModeCell
        }
        
        return UITableViewCell()
    }
}
