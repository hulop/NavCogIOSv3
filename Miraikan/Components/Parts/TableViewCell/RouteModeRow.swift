//
//  RouteModeRow.swift
//  NavCog3
//
//  Created by yoshizawr204 on 2023/01/25.
//  Copyright © 2023 HULOP. All rights reserved.
//

import Foundation
import UIKit

/**
 Caution: This is related to but not the same as the modes in NavCog3
 */

class RouteModeRow: BaseRow {
    
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
