//
//
//  NavButtonRow.swift
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

class NavButtonRow: BaseRow {

    private let btnNavi = StyledButton()

    private let gapX: CGFloat = 20
    private let gapY: CGFloat = 4
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        btnNavi.setTitle(NSLocalizedString("Guide to this exhibition", comment: ""), for: .normal)
        btnNavi.sizeToFit()
        addSubview(btnNavi)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func configure(nodeId: String, title: String?) {
        btnNavi.tapAction({ [weak self] _ in
            guard let self = self else { return }
            guard let nav = self.nav else { return }
            AudioGuideManager.shared.isDisplayButton(false)
            nav.openMap(nodeId: nodeId)
        })
        
        if let title = title {
            btnNavi.accessibilityLabel = String(format: NSLocalizedString("Guide to %@", comment: ""), title)
        }
    }

    public func configure(locations : [ExhibitionLocation], title : String) {
        btnNavi.tapAction({ [weak self] _ in
            guard let self = self else { return }
            guard let nav = self.nav else { return }
            AudioGuideManager.shared.isDisplayButton(false)
            let vc = FloorSelectionController(title: title)
            vc.items = locations
            nav.show(vc, sender: nil)
        })
    }

    override func layoutSubviews() {
        btnNavi.frame = CGRect(x: innerSize.width - btnNavi.frame.width - gapX,
                               y: insets.top + gapY,
                               width: btnNavi.intrinsicContentSize.width + btnNavi.paddingX,
                               height: btnNavi.intrinsicContentSize.height)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let height = insets.top + insets.bottom + btnNavi.intrinsicContentSize.height
        return CGSize(width: size.width, height: height + gapY * 2)
    }
}
