//
//
//  ScheduleRow.swift
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

/**
 The customized UITableViewCell for schedule item
 */
class ScheduleRow: BaseRow {
    private let lblTime = UILabel()
    private let lblPlace = UnderlinedLabel()
    private let lblEvent = UnderlinedLabel()
    private var lblDescription = AutoWrapLabel()
    
    private let gapX: CGFloat = 20
    private let gapY: CGFloat = 10
    private let gapLine: CGFloat = 5
    
    // MARK: init
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        addSubview(lblTime)
        addSubview(lblPlace)
        addSubview(lblEvent)
        addSubview(lblDescription)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /**
     Set the data from DataSource
     */
    public func configure(_ model: ScheduleRowModel) {
        
        lblTime.font = .preferredFont(forTextStyle: .callout)
        lblDescription.font = .preferredFont(forTextStyle: .callout)
        
        lblTime.text = model.schedule.time
        lblTime.sizeToFit()
        
        let lang = NSLocalizedString("lang", comment: "")

        if lang == "ja" {
            lblPlace.title = model.floorMap.title
            lblPlace.accessibilityLabel = model.floorMap.titlePron
        } else {
            lblPlace.title = model.floorMap.titleEn
            lblPlace.accessibilityLabel = model.floorMap.titleEn
        }
        lblPlace.openView({ [weak self] _ in
            guard let self = self else { return }
            if let nav = self.nav {
                nav.show(FloorMapViewController(model: model.floorMap, title: model.floorMap.title), sender: nil)
            }
        })
        addSubview(lblPlace)
        
        let talkTitle: String?
        if let _talkTitle = model.event.talkTitle {
            talkTitle = "「\(_talkTitle)」"
        } else { talkTitle = nil }
        var eventTitle = ""
        if lang == "ja" || model.event.titleEn == nil {
            eventTitle = talkTitle ?? model.event.title.replacingOccurrences(of: "\n", with: "")
        } else if let titleEn = model.event.titleEn {
            eventTitle = talkTitle ?? titleEn.replacingOccurrences(of: "\n", with: "")
        }
        
        if let viewType = model.schedule.viewType,
           let viewTypeList = model.event.viewType {
            for viewTypeData in viewTypeList {
                if viewType == viewTypeData.id {
                    eventTitle = viewTypeData.name + " " + eventTitle
                    break
                }
            }
        }

        if let type = model.schedule.type,
           let typeList = model.event.type {
            for typeData in typeList {
                if type == typeData.id {
                    if lang == "ja" {
                        eventTitle += " " + typeData.name
                    } else if let nameEn = typeData.nameEn {
                        eventTitle += " " + nameEn
                    }
                    break
                }
            }
        }
        
        lblEvent.title = eventTitle
        lblEvent.sizeToFit()
        lblEvent.openView({ [weak self] _ in
            guard let self = self else { return }
            if let nav = self.nav {
                nav.show(EventDetailViewController(model: model, title: model.event.title), sender: nil)
            }
        })
        
        var option = ""
        var optionPron = ""
        if let description = model.schedule.description {
            option += description
            optionPron += description
        }
        
        if let runningTime = model.schedule.runningTime,
           runningTime > 0 {
            if option.count > 0 {
                option += " "
            }
            option += String(format: NSLocalizedString("Run Time", comment: ""), String(runningTime))
            optionPron += String(format: NSLocalizedString("Run Time", comment: ""), String(runningTime))
        }

        if let reserve = model.schedule.reserve,
           reserve {
            if option.count > 0 {
                option += " "
            }
            option += NSLocalizedString("Reservation required", comment: "")
            optionPron += NSLocalizedString("Reservation required pron", comment: "")
        }

        if !option.isEmpty {
            lblDescription.text = option
        } else {
            lblDescription.text = ""
        }
        lblDescription.sizeToFit()
        lblDescription.isAccessibilityElement = false
        
        
        var accessibility = ""
        
        let times = model.schedule.time.components(separatedBy: ":")
        if times.count > 1 {
            if times[1] != "00" {
                accessibility += String(format: NSLocalizedString("accessibility hour minute", comment: ""), String(times[0]), String(times[1]))
            } else {
                accessibility += String(format: NSLocalizedString("accessibility hour", comment: ""), String(times[0]), String(times[1]))
            }
            accessibility += NSLocalizedString("TTS_PAUSE_CHAR", tableName: "BlindView", comment: "")
        }
        
        if lang == "ja" {
            accessibility += model.floorMap.titlePron
        } else {
            accessibility += model.floorMap.titleEn
        }
        accessibility += NSLocalizedString("TTS_PAUSE_CHAR", tableName: "BlindView", comment: "")

        if !eventTitle.isEmpty {
            accessibility += eventTitle
            accessibility += NSLocalizedString("TTS_PAUSE_CHAR", tableName: "BlindView", comment: "")
        }
        
        if !option.isEmpty {
            accessibility += optionPron
        }
        lblTime.accessibilityLabel = accessibility
    }

    // MARK: layout
    override func layoutSubviews() {
        super.layoutSubviews()
        
        var y = insets.top + gapY

        lblTime.frame.origin.x = insets.left + gapX
        
        let leftColWidth = lblTime.frame.origin.x + lblTime.frame.width + gapX
        lblPlace.frame = CGRect(x: leftColWidth,
                                y: y,
                                width: frame.width - leftColWidth - insets.right,
                                height: lblPlace.intrinsicContentSize.height)
        y += lblPlace.frame.height + gapLine

        lblTime.center.y = lblPlace.center.y

        let rightColWidth = innerSize.width - leftColWidth - gapX
        let eventWidth = min(rightColWidth, lblEvent.intrinsicContentSize.width)
        let szFit = CGSize(width: eventWidth, height: lblEvent.intrinsicContentSize.height)
        lblEvent.frame = CGRect(x: leftColWidth,
                                y: y,
                                width: eventWidth,
                                height: lblEvent.sizeThatFits(szFit).height)

        y += lblEvent.frame.height + gapLine
        
        let descriptionWidth = min(rightColWidth, lblDescription.intrinsicContentSize.width)
        let szDescriptionFit = CGSize(width: descriptionWidth, height: lblDescription.intrinsicContentSize.height)
        lblDescription.frame = CGRect(x: leftColWidth,
                                y: y,
                                width: descriptionWidth,
                                height: lblDescription.sizeThatFits(szDescriptionFit).height)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var y = insets.top + gapY
        let x = insets.left + gapX

        let leftColWidth = x + lblTime.frame.width + gapX
        var szFit = CGSize(width: frame.width - leftColWidth - insets.right,
                           height: lblPlace.intrinsicContentSize.height)
        y += lblPlace.sizeThatFits(szFit).height + gapLine

        let rightColWidth = innerSize.width - leftColWidth - gapX
        let eventWidth = min(rightColWidth, lblEvent.intrinsicContentSize.width)
        szFit = CGSize(width: eventWidth,
                       height: lblEvent.intrinsicContentSize.height)
        y += lblEvent.sizeThatFits(szFit).height + gapLine

        if lblDescription.frame.width > 0 {
            let descriptionWidth = min(rightColWidth, lblDescription.intrinsicContentSize.width)
            szFit = CGSize(width: descriptionWidth,
                           height: lblDescription.intrinsicContentSize.height)
            y += lblDescription.sizeThatFits(szFit).height + gapLine
        }
        y += gapY

        return CGSize(width: size.width, height: y)
    }
}
