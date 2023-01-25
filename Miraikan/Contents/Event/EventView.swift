//
//  EventView.swift
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
 The content of the  UIScrollView of EventView
 */
fileprivate class EventContent: BaseView {
    private var btnNavi : StyledButton?
    private var lblTitle: UILabel!
    private var lblSubtitle: UILabel?
    private var scheduleLabels = [UILabel]()
    private var descLabels = [UILabel]()
    private var lblContent: UILabel!
    
    private let image: UIImage!
    private let imgView: UIImageView!
    
    private let type: ImageType
    private let gap = CGFloat(15)
    
    private let facilityId: String?

    private var map: UIImageView!
    private var mapImage: UIImage!

    private let lblMapTitle = UILabel()
    private let lblPlace = UILabel()
    private let btnNav = StyledButton()
    
    var navigationAction: (()->())?
    var notificationAction: (()->())?

    // MARK: init
    init(_ eventModel: EventModel, mapModel: FloorMapModel?, facilityId: String?) {
        self.facilityId = facilityId
        self.type = ImageType(rawValue: eventModel.imageType.uppercased())!
        let imageCoStudio = "co_studio"
        let imageName = eventModel.id.contains(imageCoStudio)
            ? imageCoStudio
            : eventModel.id
        self.image = UIImage(named: imageName)
        self.imgView = UIImageView(image: self.image)
        
        super.init(frame: .zero)
        setupEvent(eventModel)
        if let mapModel = mapModel {
            setupFloorMap(mapModel)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: layout
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let safeSize = CGSize(width: innerSize.width, height: frame.height)
        
        var y = insets.top
        if let btnNavi = btnNavi {
            btnNavi.frame = CGRect(x: insets.left,
                                   y: y + gap,
                                   width: btnNavi.intrinsicContentSize.width + btnNavi.paddingX,
                                   height: btnNavi.intrinsicContentSize.height)
            y += btnNavi.frame.height + gap * 2
        }
        lblTitle.frame = CGRect(x: insets.left,
                                y: y,
                                width: innerSize.width,
                                height: lblTitle.sizeThatFits(safeSize).height)
        y += lblTitle.frame.height + gap
        
        let imgAdaptor = ImageAdaptor(img: image)
        let scaledSize = imgAdaptor.scaleImage(viewSize: type.size,
                                               frameWidth: frame.width)
        imgView.frame = CGRect(x: insets.left,
                               y: y,
                               width: scaledSize.width - insets.left * 2,
                               height: scaledSize.height)
        y += imgView.frame.height + gap
        
        scheduleLabels.forEach({
            $0.frame = CGRect(x: insets.left,
                              y: y,
                              width: innerSize.width,
                              height: $0.sizeThatFits(safeSize).height)
            y += $0.frame.height + CGFloat(5)
        })
        y += gap
        
        lblContent.frame = CGRect(x: insets.left,
                                  y: y,
                                  width: innerSize.width,
                                  height: lblContent.sizeThatFits(safeSize).height)
        y += lblContent.frame.height + gap
        
        descLabels.forEach({
            $0.frame = CGRect(x: insets.left,
                              y: y,
                              width: innerSize.width,
                              height: $0.sizeThatFits(safeSize).height)
            y += $0.frame.height + CGFloat(5)
        })
        y += gap

        // Floor
        lblMapTitle.frame.origin = CGPoint(x: insets.left, y: y)
        y += lblMapTitle.frame.height + gap
        
        lblPlace.frame.origin = CGPoint(x: insets.left, y: y)
        y += lblPlace.frame.height + gap

        let mapImgAdaptor = ImageAdaptor(img: mapImage)
        let mapScaledSize = mapImgAdaptor.scaleImage(viewSize: ImageType.FLOOR_MAP.size,
                                               frameWidth: frame.width)
        map.frame = CGRect(x: 0,
                           y: y,
                           width: mapScaledSize.width,
                           height: mapScaledSize.height)
        y += map.frame.height + gap
        
        btnNav.center.x = center.x
        btnNav.frame.origin.y = y
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let safeSize = innerSizing(parentSize: size)
        var height = insets.top
        
        height += lblTitle.sizeThatFits(safeSize).height + gap
        
        height += imgView.frame.height + gap
        
        if scheduleLabels.count > 0 {
            scheduleLabels.forEach({ height += $0.sizeThatFits(safeSize).height })
            height += gap
        }
        
        height += lblContent.sizeThatFits(safeSize).height + gap
        
        if descLabels.count > 0 {
            descLabels.forEach({ height += $0.sizeThatFits(safeSize).height })
            height += gap
        }
        
        height += lblMapTitle.frame.height + gap
        height += lblPlace.frame.height + gap
        height += map.frame.height + gap
        height += btnNav.frame.height + gap

        return CGSize(width: size.width, height: height)
    }
    
    // MARK: Private functions
    private func setupEvent(_ model: EventModel) {
        
        btnNavi = StyledButton()
        guard let btnNavi = btnNavi else { return }
        btnNavi.setTitle(NSLocalizedString("Guide to this exhibition", comment: ""), for: .normal)
        btnNavi.titleLabel?.numberOfLines = 0
        btnNavi.titleLabel?.lineBreakMode = .byWordWrapping
        btnNavi.sizeToFit()
        
        var nodeId: String?
        if let floorMaps = MiraikanUtil.readJSONFile(filename: "floor_map",
                                     type: [FloorMapModel].self) as? [FloorMapModel],
           let floorMap = floorMaps.first(where: {$0.id == facilityId}) {
            nodeId = floorMap.nodeId
            btnNavi.tapAction({ [weak self] _ in
                guard let self = self else { return }
                guard let nav = self.navVC else { return }
                AudioGuideManager.shared.isDisplayButton(false)
                nav.openMap(nodeId: nodeId)
            })
        }
        addSubview(btnNavi)

        func createLabel(_ txt: String) -> UILabel {
            let lbl = UILabel()
            lbl.text = txt
            lbl.numberOfLines = 0
            lbl.lineBreakMode = .byWordWrapping
            return lbl
        }
        
        lblTitle = createLabel(model.title)
        lblTitle.font = .preferredFont(forTextStyle: .title2)
        addSubview(lblTitle)
        
        addSubview(imgView)
        
        if let schedules = model.schedule {
            schedules.forEach({
                let lbl = createLabel($0)
                lbl.font = .preferredFont(forTextStyle: .callout)
                scheduleLabels += [lbl]
                addSubview(lbl)
            })
        }
        
        lblContent = createLabel(model.content)
        addSubview(lblContent)
        
        if let descList = model.description {
            descList.forEach({
                let lbl = createLabel("※\($0)")
                lbl.font = .preferredFont(forTextStyle: .footnote)
                lbl.textColor = .darkGray
                descLabels += [lbl]
                addSubview(lbl)
            })
        }
    }
    
    private func setupFloorMap(_ model: FloorMapModel) {

        lblMapTitle.font = .preferredFont(forTextStyle: .title2)
        lblPlace.font = .preferredFont(forTextStyle: .title3)

        lblMapTitle.text = model.title
        let floor = String(model.floor)
        var floorText = String(format: NSLocalizedString("FloorD", tableName: "BlindView", comment: "floor"), floor)

        if let counter = model.counter {
            // If the map exists, use it.
            floorText += "   " + counter.uppercased()
            mapImage = UIImage(named: "f\(floor)_\(counter)")
        } else {
            // Otherwise, use the placeholder
            mapImage = UIImage(named: "no_map")
        }
        map = UIImageView(image: mapImage)

        lblPlace.text = floorText
        [lblMapTitle, lblPlace].forEach({
            $0.textColor = .black
            $0.sizeToFit()
            addSubview($0)
        })
        
        addSubview(map)
        
        btnNav.setTitle(String(format: NSLocalizedString("Guide to", comment: ""), (model.title)), for: .normal)
        btnNav.titleLabel?.numberOfLines = 0
        btnNav.titleLabel?.lineBreakMode = .byWordWrapping
        btnNav.sizeToFit()
        btnNav.tapAction { [weak self] _ in
            guard let self = self else { return }
            if let _f = self.navigationAction {
                _f()
            }
        }
        addSubview(btnNav)
    }
}

/**
 The UIScrollView of event details
 */
class EventView: BaseScrollView {
    init(_ eventModel: EventModel, mapModel: FloorMapModel?, facilityId: String?) {
        super.init(frame: .zero)
        
        contentView = EventContent(eventModel, mapModel:mapModel, facilityId: facilityId)
        scrollView.addSubview(contentView)
        addSubview(scrollView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
