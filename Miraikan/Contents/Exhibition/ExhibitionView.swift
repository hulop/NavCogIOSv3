//
//  ExhibitionView.swift
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
import WebKit

/**
 Layout for exhibition details
 
 - Parameters:
 - category: The URL parameter for category
 - id: The URL parameter for a specific exhibition
 - nodeId: The destination id for navigation
 - permalink: The URL component for a specific event
 */
class ExhibitionView: BaseWebView, WebAccessibilityDelegate {
    private var btnNavi : StyledButton?
    private var lblDetail : AutoWrapLabel?

    private let gapX: CGFloat = 20
    private let gapY: CGFloat = 0
    
    private let id: String?
    private var nodeId: String?
    private var isWebFailed : Bool = false

    
    // MARK: init
    init(category: String? = nil, id: String? = nil, nodeId: String?, detail : String? = nil, locations: [ExhibitionLocation]?) {
        self.id = id
        self.nodeId = nodeId
        super.init(frame: .zero)
        
        self.accessibilityDelegate = self
        
        btnNavi = StyledButton()
        guard let btnNavi = btnNavi else { return }
        btnNavi.setTitle(NSLocalizedString("Guide to this exhibition", comment: ""), for: .normal)
        btnNavi.sizeToFit()
        btnNavi.tapAction({ [weak self] _ in
            guard let self = self else { return }
            guard let nav = self.navVC else { return }
            AudioGuideManager.shared.isDisplayButton(false)
            if let nodeId = self.nodeId {
                nav.openMap(nodeId: nodeId)
            }
            if let locations = locations {
                let vc = FloorSelectionController(title: nav.title)
                vc.items = [0: locations]
                nav.show(vc, sender: nil)
            }
        })
        addSubview(btnNavi)
        
        if MiraikanUtil.routeMode == .blind, let detail = detail {
            let inner = detail.replacingOccurrences(of: "\n", with: "<br/>")
            let html = "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"></head><p sytle='font-size: 18px;'>\(inner)</p>"
            loadDetail(html: html)
        } else if let category = category, let id = id {
            let mid = category == "calendar" ? category : "exhibitions/\(category)"
            let address = "\(MiraikanUtil.miraikanHost)/\(mid)/\(id)/"
            loadContent(address)
        }
    }
    
    init(permalink: String) {
        self.id = nil
        super.init(frame: .zero)
        self.accessibilityDelegate = self
        let address = "\(Host.miraikan.address)/\(permalink)"
        loadContent(address)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: layout
    override func layoutSubviews() {
        super.layoutSubviews()
        
        var y = insets.top
        if let btnNavi = btnNavi {
            btnNavi.frame = CGRect(x: insets.left + gapX,
                                   y: y + gapY,
                                   width: btnNavi.intrinsicContentSize.width + btnNavi.paddingX,
                                   height: btnNavi.intrinsicContentSize.height)
            y += btnNavi.frame.height + gapY * 2
        }

        // Loaded
        webView.frame = CGRect(x: insets.left,
                               y: y,
                               width: innerSize.width,
                               height: innerSize.height - y + insets.top - gapY * 2)
    }
    
    func onFinished() {
        if let btnNavi = btnNavi {
            UIAccessibility.post(notification: .screenChanged, argument: btnNavi)
        } else {
            UIAccessibility.post(notification: .screenChanged, argument: self.parentVC?.title)
        }
    }
    
}
