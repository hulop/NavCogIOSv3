//
//
//  DistanceCheckView.swift
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
 The content of the  UIScrollView of EventView
 */
fileprivate class DistanceCheckContent: BaseView {
    private let tts = DefaultTTS()
    private var isPlaying = false
    private var items: [LandmarkModel] = []
    private var nearestItems = [PositionModel?](repeating: nil, count: 6)
    private var speakTexts: [String] = []

    private var lblTitleArray: [UILabel] = []
    private var lblLatitude = UILabel()
    private var lbllongitude = UILabel()
    private var lblFloor = UILabel()
    private var lblSpeed = UILabel()
    private var lblAccuracy = UILabel()
    private var lblOrientation = UILabel()
    private var lblOrientationAccuracy = UILabel()

    private var lblLocationTitleArray: [UILabel] = []
    private var lblLocationDistanceArray: [UILabel] = []

    private var checkLocation: HLPLocation?
    private var locationChangedTime = Date().timeIntervalSince1970
    
    private var filePath: URL?

    private let gap: CGFloat = 5
    private let space: CGFloat = 10

    private let checkTime: Double = 1
    private let checkDistance: Double = 1.2
    
    private let nearestFront: Double = 9
    private let nearestSide: Double = 7
    private let nearestRear: Double = 5

    private let angleFront: Double = 20
    private let angleSide: Double = 110
    private let angleRear: Double = 150

    // MARK: init
    init() {
        super.init(frame: .zero)

        setupLocationList()
        
        setFilePath()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: layout
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let safeSize = CGSize(width: innerSize.width, height: frame.height)
        
        var y = insets.top
        
        for (index, lblTitle) in lblTitleArray.enumerated() {
            lblTitle.frame = CGRect(x: insets.left + gap,
                                    y: y,
                                    width: (innerSize.width - gap) / 2 ,
                                    height: lblTitle.sizeThatFits(safeSize).height)
            if let label = getLabel(index: index) {
                label.frame = CGRect(x: insets.left + innerSize.width / 2 + gap,
                                     y: y,
                                     width: (innerSize.width - gap) / 2 ,
                                     height: lblTitle.sizeThatFits(safeSize).height)
            }
            y += lblTitle.frame.height + gap
        }
        
        y += space
        
        for (index, lblLocationTitle) in lblLocationTitleArray.enumerated() {
            lblLocationTitle.frame = CGRect(x: insets.left + gap,
                                    y: y,
                                    width:(innerSize.width - gap) / 2 ,
                                    height: lblLocationTitle.sizeThatFits(safeSize).height)
            
            let label = lblLocationDistanceArray[index]
            label.frame = CGRect(x: insets.left + innerSize.width / 2 + gap,
                                 y: y,
                                 width: (innerSize.width - gap) / 2 ,
                                 height: lblLocationTitle.sizeThatFits(safeSize).height)

            y += lblLocationTitle.frame.height + gap
        }
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let safeSize = innerSizing(parentSize: size)
        var height = insets.top
        
        for lblTitle in lblTitleArray {
            height += lblTitle.sizeThatFits(safeSize).height + gap
        }

        height += space

        for lblLocationTitle in lblLocationTitleArray {
            height += lblLocationTitle.sizeThatFits(safeSize).height + gap
        }

        return CGSize(width: size.width, height: height)
    }

    private func createLabel(_ txt: String) -> UILabel {
        let lbl = UILabel()
        lbl.text = txt
        lbl.numberOfLines = 1
        lbl.lineBreakMode = .byWordWrapping
        return lbl
    }
    
    // MARK: Private functions
    private func setupLocationList() {
        let locationInfoes = [
            "latitude",
            "longitude",
            "floor",
            "speed",
            "accuracy",
            "orientation",
            "orientationAccuracy"
        ]

        for locationInfo in locationInfoes {
            let label = createLabel(locationInfo)
            lblTitleArray.append(label)
            addSubview(label)
        }

        addSubview(lblLatitude)
        addSubview(lbllongitude)
        addSubview(lblFloor)
        addSubview(lblSpeed)
        addSubview(lblAccuracy)
        addSubview(lblOrientation)
        addSubview(lblOrientationAccuracy)
    }
        
    private func setupFloorList() {
        for item in items {
            let label = createLabel(item.title)
            lblLocationTitleArray.append(label)
            addSubview(label)

            let distanceLabel = UILabel()
            lblLocationDistanceArray.append(distanceLabel)
            addSubview(distanceLabel)
        }
    }

    private func getLabel(index: Int) -> UILabel? {
        switch index {
        case 0:
            return lblLatitude
        case 1:
            return lbllongitude
        case 2:
            return lblFloor
        case 3:
            return lblSpeed
        case 4:
            return lblAccuracy
        case 5:
            return lblOrientation
        case 6:
            return lblOrientationAccuracy
        default:
            return nil
        }
    }

    func setDataForFloor(floor: Int) {
        guard let navDataStore = NavDataStore.shared(),
              let destinations = navDataStore.destinations() else { return }

        DispatchQueue.main.async{
            self.items.removeAll()
            
            for label in self.lblLocationTitleArray {
                label.removeFromSuperview()
            }
            self.lblLocationTitleArray = []

            for label in self.lblLocationDistanceArray {
                label.removeFromSuperview()
            }
            self.lblLocationDistanceArray = []

            for landmark in destinations {
                if let landmark = landmark as? HLPLandmark,
                   Int(landmark.nodeHeight) + 1 == floor,
                   !landmark.name.isEmpty,
                   let id = landmark.properties[PROPKEY_FACILITY_ID] as? String,
                   let coordinates = landmark.geometry.coordinates,
                   let latitude = coordinates[1] as? Double,
                   let longitude = coordinates[0] as? Double {
                    let linkModel = LandmarkModel(id: id,
                                                  nodeId: landmark.nodeID,
                                                  groundFloor: Int(landmark.nodeHeight),
                                                  title: landmark.name,
                                                  titlePron: landmark.namePron,
                                                  nodeLocation: landmark.nodeLocation,
                                                  spotLocation: HLPLocation(lat: latitude, lng: longitude))
                    self.items.append(linkModel)
                    NSLog("\(linkModel.id)")

                    if self.items.first(where: {$0.nodeId == id }) == nil {
                        let linkModel = LandmarkModel(id: id,
                                                      nodeId: id,
                                                      groundFloor: Int(landmark.nodeHeight),
                                                      title: landmark.name,
                                                      titlePron: landmark.namePron,
                                                      nodeLocation: HLPLocation(lat: latitude, lng: longitude),
                                                      spotLocation: HLPLocation(lat: latitude, lng: longitude))
                        self.items.append(linkModel)
                        NSLog("\(linkModel.id)")
                    }
                }
            }
            self.setupFloorList()
        }
    }

    func locationChanged(current: HLPLocation) {

        var updateDistance = false
        let now = Date().timeIntervalSince1970
        if !current.lat.isNaN && !current.lng.isNaN && (locationChangedTime + checkTime < now) {

            if checkLocation == nil {
                locationChangedTime = now
                checkLocation = current
                return
            }

            let distance = current.distance(to: checkLocation)
//            NSLog("distance = \(distance), \(current), \(checkLocation) ")
            if distance < checkDistance {
                return
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.calendar = Calendar(identifier: .gregorian)
            dateFormatter.locale = Locale(identifier: "ja_JP")
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            let dateString = dateFormatter.string(from: Date())

            guard let checkLocation = checkLocation else { return }
            let checkPoint = CGPoint(x: checkLocation.lat, y: checkLocation.lng)
            let currentPoint = CGPoint(x: current.lat, y: current.lng)
            let vector = Line(from: checkPoint, to: currentPoint)
            locationChangedTime = now
            self.checkLocation = current

            updateDistance = true

            for item in self.items {
                item.distance = current.distance(to: item.nodeLocation)
            }
            
            var sortItems = self.items.filter({ $0.distance <= nearestFront })
            sortItems.sort(by: { $0.distance < $1.distance})
            
            var positionModels: [PositionModel] = []

            for item in sortItems {
                if self.nearestItems.first(where: {$0?.id == item.id }) == nil,
                   positionModels.first(where: {$0.id == item.id }) == nil {
                    let destination = CGPoint(x: item.spotLocation.lat, y: item.spotLocation.lng)
                    let lineSegment = Line(from: currentPoint, to: destination)
                    
                    let sita = Line.angle(vector, lineSegment)
                    let sitaPi = sita * 180.0 / Double.pi
                    
                    if sitaPi < angleFront ||
                        sitaPi < angleSide && item.distance < nearestSide ||
                        sitaPi < angleRear && item.distance < nearestRear {

                        let positionModel = PositionModel(id: item.id, titlePron: item.titlePron)
                        positionModel.distance = item.distance
                        let isRightDirection = Line.isRightDirection(vector, point: destination)
                        positionModel.angle = sitaPi * (isRightDirection ? -1 : 1)
                        positionModels.append(positionModel)

                        self.writeData("\(dateString), \(current.lat), \(current.lng), \(checkLocation.lat), \(checkLocation.lng), \(isRightDirection), \(Double(sita)), \(Double(sitaPi)), \(item.distance)m, \(item.titlePron), \(destination.x), \(destination.y), \(positionModels.count)\n")
                    }
                }
            }

            for item in positionModels {
                self.nearestItems.removeFirst()
                self.nearestItems.append(item)
                
                var localizeKey = ""
                if fabs(item.angle) < angleFront {
                    localizeKey = "InTheFront"
                } else if fabs(item.angle) < angleRear {
                    localizeKey = item.angle < 0 ? "OnTheLeftSide" : "OnTheRightSide"
                }

                if !localizeKey.isEmpty {
                    self.speakTexts.append(String(format: NSLocalizedString(localizeKey, tableName: "BlindView", comment: ""), item.titlePron))
                }
            }
            
            if positionModels.count > 0 {
                self.dequeueSpeak()
            }
        }

        DispatchQueue.main.async{ [self] in
            self.lblLatitude.text = String(current.lat)
            self.lbllongitude.text = String(current.lng)
            self.lblFloor.text = String(current.floor + 1)
            self.lblSpeed.text = String(current.speed)
            self.lblAccuracy.text = String(current.accuracy)
            self.lblOrientation.text = String(current.orientation)
            self.lblOrientationAccuracy.text = String(current.orientationAccuracy)
            
            if updateDistance {
                for (index, item) in self.items.enumerated() {
                    self.lblLocationDistanceArray[index].text = String(item.distance )
                }
            }
        }
    }

    private func pause() {
        tts.stop(true)
        self.isPlaying = false
    }

    private func play(text: String) {
        if self.isPlaying { return }

        self.isPlaying = true
        tts.speak(text, callback: { [weak self] in
            guard let self = self else { return }
            self.isPlaying = false
            self.dequeueSpeak()
        })
    }

    private func dequeueSpeak() {
        if self.isPlaying { return }
        if let text = speakTexts.first {
            self.play(text: text)
            self.speakTexts.removeFirst()
        }
    }
}

extension DistanceCheckContent {

    func setFilePath() {
        if !UserDefaults.standard.bool(forKey: "DebugMode") {
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = "yyyyMMddHHmm"
        let dateString = dateFormatter.string(from: Date())
        if let dir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first {
            filePath = dir.appendingPathComponent("institution\(dateString).csv")
            guard let filePath = filePath else { return }
            if FileManager.default.createFile(
                            atPath: filePath.path,
                            contents: nil,
                            attributes: nil
                            )
            {
            }
        }
    }
    
    func writeData(_ writeLine: String) {
        if !UserDefaults.standard.bool(forKey: "DebugMode") {
            return
        }
        guard let filePath = filePath else {
            return
        }
        if let file = FileHandle(forWritingAtPath: filePath.path),
           let data = writeLine.data(using: .utf8) {
            file.seekToEndOfFile()
            file.write(data)
        }
    }
}

/**
 The UIScrollView of event details
 */
class DistanceCheckView: BaseScrollView {
    init() {
        super.init(frame: .zero)
        
        contentView = DistanceCheckContent()
        scrollView.addSubview(contentView)
        addSubview(scrollView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func locationChanged(current: HLPLocation) {
        if let contentView = contentView as? DistanceCheckContent {
            contentView.locationChanged(current: current)
        }
    }

    func floorChanged(floor: Int) {
        if let contentView = contentView as? DistanceCheckContent {
            contentView.setDataForFloor(floor: floor)
        }
        
        DispatchQueue.main.async{
            self.scrollView.contentSize = CGSize(width: self.contentView.frame.width, height: 1500)
        }
    }
}
