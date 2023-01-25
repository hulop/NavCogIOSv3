//
//
//  EventDetailView.swift
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

class EventDetailView: UIView {

    var model: ScheduleRowModel?
    var navigationAction: (()->())?
    var notificationAction: (()->())?

    @IBOutlet weak var btnNavi: StyledButton!
    @IBOutlet weak var lblScheduleTime: UILabel!
    @IBOutlet weak var btnScheduleTime: StyledButton!
    
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var eventImgView: UIImageView!
    @IBOutlet weak var scheduleLabel: UILabel!
    @IBOutlet weak var descLabel: UILabel!
    @IBOutlet weak var lblContent: UILabel!

    @IBOutlet weak var lblMapTitle: UILabel!
    @IBOutlet weak var lblPlace: UILabel!
    @IBOutlet weak var floorMapImgView: UIImageView!
    @IBOutlet weak var btnFloor: StyledButton!

    @IBOutlet weak var scheduleTimeView: UIView!
    @IBOutlet weak var scheduleView: UIView!
    @IBOutlet weak var descView: UIView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var floorMapView: UIView!

    @IBOutlet weak var eventImgViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var floorMapImgViewHeightConstraint: NSLayoutConstraint!
    
    private let margin: CGFloat = 20

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.nibInit()
        self.setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.nibInit()
        self.setup()
    }
    
    fileprivate func nibInit() {
        guard let view = UINib(nibName: "EventDetailView", bundle: nil).instantiate(withOwner: self, options: nil).first as? UIView else {
            return
        }

        view.frame = self.bounds
        view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        self.addSubview(view)
    }

    init(_ model: ScheduleRowModel) {
        super.init(frame: .zero)

        self.model = model

        self.nibInit()
        self.setup()
    }
    
    func setup() {
        btnNavi.setTitle(NSLocalizedString("Guide to this exhibition", comment: ""), for: .normal)
        btnNavi.sizeToFit()
        btnNavi.tapAction { [weak self] _ in
            guard let self = self else { return }
            if let _f = self.navigationAction {
                _f()
            }
        }

        if let schedule = model?.schedule {
            
            lblScheduleTime.text = schedule.time
            
            if schedule.place == "co_studio" {
                btnScheduleTime.tapAction { [weak self] _ in
                    guard let self = self else { return }
                    AudioGuideManager.shared.isDisplayButton(false)
                    if let _f = self.notificationAction {
                        _f()
                    }
                }
            } else {
                scheduleTimeView.isHidden = true
            }
        }
        
        if let eventModel = model?.event {
            var title = eventModel.title
            if let talkTitle = eventModel.talkTitle {
                title += "\n「\(talkTitle)」"
            }
            lblTitle.text = title
            
            if let schedule = eventModel.schedule {
                let schedules = schedule.joined(separator: "\n")
                scheduleLabel.text = schedules
            } else {
                scheduleView.isHidden = true
            }

            let imageName = eventModel.id
            if let image = UIImage(named: imageName) {
                let scale = (UIScreen.main.bounds.width - margin * 2) / image.size.width
                eventImgViewHeightConstraint.constant = image.size.height * scale
                eventImgView.image = image
            } else if let imagePlace = model?.schedule.place,
                let image = UIImage(named: imagePlace) {
                let scale = (UIScreen.main.bounds.width - margin * 2) / image.size.width
                eventImgViewHeightConstraint.constant = image.size.height * scale
                eventImgView.image = image
            }

            lblContent.text = eventModel.content
            if eventModel.content.isEmpty {
                contentView.isHidden = true
            }

            if let descList = eventModel.description {
                var descriptions: [String] = []
                descList.forEach({
                    descriptions.append("※\($0)")
                })
                descLabel.text = descriptions.joined(separator: "\n")
            } else {
                descView.isHidden = true
            }
        }
        
        if let mapModel = model?.floorMap {
            lblMapTitle.text = mapModel.title

            var floorMapViewHidden = true

            let floor = String(mapModel.floor)
            var floorText = String(format: NSLocalizedString("FloorD", tableName: "BlindView", comment: "floor"), floor)
            if let counter = mapModel.counter {
                floorText += "   " + counter.uppercased()
                if let mapImage = UIImage(named: "f\(floor)_\(counter)") {
                    let scale = (UIScreen.main.bounds.width - margin * 2) / mapImage.size.width
                    floorMapImgViewHeightConstraint.constant = mapImage.size.height * scale
                    floorMapImgView.image = mapImage
                    floorMapViewHidden = false
                }
            }
            floorMapView.isHidden = floorMapViewHidden
            lblPlace.text = floorText

            btnFloor.setTitle(String(format: NSLocalizedString("Guide to", comment: ""), (mapModel.title)), for: .normal)
            btnFloor.sizeToFit()
            btnFloor.tapAction { [weak self] _ in
                guard let self = self else { return }
                if let _f = self.navigationAction {
                    _f()
                }
            }
        }
    }
}
