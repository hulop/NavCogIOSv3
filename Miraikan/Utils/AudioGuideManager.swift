//
//
//  AudioGuideManager.swift
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

// Singleton
final public class AudioGuideManager: NSObject {
    
    private var temporaryFloor = 0
    private var currentFloor = 0
    private var continueFloorCount = 0

    private let tts = DefaultTTS()
    private var isPlaying = false
    private var items: [LandmarkModel] = []
    private var landmarks: [LandmarkModel] = []
    private var nearestItems = [PositionModel?](repeating: nil, count: 8)
    private var speakTexts: [String] = []
    private var guidePositions: [GuidePositionModel] = []
    private var checkPointPositions: [GuidePositionModel] = []
    private var sectionItems: [HLPSectionModel] = []
    private var additionalLocations: [AdditionalLocationModel] = []
    private var floorPlans: [FloorPlanModel] = []

    private var floorStr = ""

    private var checkLocation: HLPLocation?
    private var locationChangedTime = Date().timeIntervalSince1970

    private var initFlag = false
    @objc dynamic var isDisplay = true
    private var isActive = true
    private var reserveFloorGuide = false

    private let checkTime: Double = 1
    private let checkDistance: Double = 1.2
    
    private let nearestFront: Double = 8
    private let nearestSide: Double = 7
    private let nearestRear: Double = 4

    private let angleFront: Double = 15
    private let angleSide: Double = 90
    private let angleRear: Double = 110

    private var filePath: URL?
    private var lang = ""

    private override init() {
        super.init()
        active()
        initGuidePosition()
        initCheckPointPosition()
        initAdditionalLocation()
        lang = NSLocalizedString("lang", comment: "")
    }

    public static let shared = AudioGuideManager()


    func isDisplayButton(_ isDisplay: Bool) {
        self.isDisplay = isDisplay
    }

    func isActive(_ isActive: Bool) {
        self.speakTexts.removeAll()
        self.isActive = isActive
    }

    func active() {
        let center = NotificationCenter.default
        center.removeObserver(self)
        center.addObserver(self,
                           selector: #selector(type(of: self).locationChanged(note:)),
                           name: NSNotification.Name("nav_location_changed_notification"),
                           object: nil)
    }

    func inactive() {
        let center = NotificationCenter.default
        center.removeObserver(self, name: NSNotification.Name("nav_location_changed_notification"), object: nil)

        checkLocation = nil
    }

    func floorPlan() {
        reserveFloorGuide = true
    }

    @objc private func locationChanged(note: Notification) {
        guard let userInfo = note.userInfo,
              let current = userInfo["current"] as? HLPLocation else {
          return
        }

        initHLPDirectory()
//        NSLog("\(current)")

        let currentFloor = current.floor < 0 ? Int(current.floor) : Int(current.floor + 1)
        if temporaryFloor == currentFloor {
            continueFloorCount += 1
        } else {
            continueFloorCount = 0
        }
        temporaryFloor = currentFloor

        if continueFloorCount > 20 &&
            self.currentFloor != temporaryFloor {
            self.currentFloor = temporaryFloor
            let floor = Int(currentFloor)
            
            self.items.removeAll()
            setDataForFloor(floor: floor)
            setCheckPointForFloor(floor: floor)

            reserveFloorGuide = true
        }

        if reserveFloorGuide {
            floorGuide(current: current)
            reserveFloorGuide = false
        }

        if !self.isDisplay { return }
        if !self.isActive { return }

        locationChanged(current: current)
    }

    func floorGuide(current: HLPLocation) {
        let previousFloorStr = floorStr
        let currentFloor = current.floor < 0 ? Int(current.floor) : Int(current.floor + 1)
        for item in floorPlans {
            if currentFloor == item.floor {
                
                floorStr = NSLocalizedString("floor \(currentFloor)" , tableName: "BlindView", comment: "")

                if !item.titlePron.isEmpty,
                   isExhibitionZone(current: current) {
                    
                    if item.floor < 7,
                       isSymbolZone(current: current) {
                        
                        for item in floorPlans {
                            if item.isSymbolZone {
                                floorStr += NSLocalizedString("TTS_PAUSE_CHAR", tableName: "BlindView", comment: "")
                                floorStr += lang == "ja" ? item.titlePron : item.titleEn
                                break
                            }
                        }
                    } else {
                        floorStr += NSLocalizedString("TTS_PAUSE_CHAR", tableName: "BlindView", comment: "")
                        floorStr += lang == "ja" ? item.titlePron : item.titleEn

                        if lang == "ja",
                           let subTitlePron = item.subTitlePron,
                           !subTitlePron.isEmpty {
                            floorStr += NSLocalizedString("TTS_PAUSE_CHAR", tableName: "BlindView", comment: "") + subTitlePron
                        } else if let subTitleEn = item.subTitleEn,
                            !subTitleEn.isEmpty {
                             floorStr += NSLocalizedString("TTS_PAUSE_CHAR", tableName: "BlindView", comment: "") + subTitleEn
                        }
                    }
                }
                break
            }
        }

        if !floorStr.isEmpty,
           previousFloorStr != floorStr {
            if UserDefaults.standard.bool(forKey: "isVoiceGuideOn") {
                self.speakTexts.append(floorStr)
                self.dequeueSpeak()
            }
        }
    }

    private func setDataForFloor(floor: Int) {
        // 新規のランドマークデータで処理する　作成中、フロアカウントの違いに注意
        // nodeLocation との距離
        // spotLocation　向き
        
        for landmark in landmarks {
            if landmark.floor == floor {
                var location: HLPLocation?
                if !landmark.title.isEmpty,
                   let guidePosition = getGuidePosition(title: landmark.title, floor: floor),
                   let latitude = Double(guidePosition.latitude),
                   let longitude = Double(guidePosition.longitude) {
                    location = HLPLocation(lat: latitude, lng: longitude)
                } else {
                    location = landmark.spotLocation
                }

                if !landmark.title.isEmpty,
                   let location = location {
                    let linkModel = LandmarkModel(id: landmark.id,
                                                  nodeId: landmark.nodeId,
                                                  groundFloor: landmark.groundFloor,
                                                  title: landmark.title,
                                                  titlePron: landmark.titlePron,
                                                  titleEn: landmark.titleEn,
                                                  nodeLocation: landmark.nodeLocation,
                                                  spotLocation: location)
                    linkModel.isExhibitionZone = landmark.isExhibitionZone
                    self.appendItem(model: linkModel)

                    if self.items.first(where: {$0.nodeId == landmark.id }) == nil,
                       !landmark.checkPointOnly {
                        let linkModel = LandmarkModel(id: landmark.id,
                                                      nodeId: landmark.id,
                                                      groundFloor: landmark.groundFloor,
                                                      title: landmark.title,
                                                      titlePron: landmark.titlePron,
                                                      titleEn: landmark.titleEn,
                                                      nodeLocation: location,
                                                      spotLocation: location)
                        linkModel.isExhibitionZone = landmark.isExhibitionZone
                        self.appendItem(model: linkModel)
                    }
                }
            }
        }
    }

    // TODO: Provisional processing
    private func setCheckPointForFloor(floor: Int) {
        for checkPointPosition in self.checkPointPositions {
            let currentFloor = checkPointPosition.floor < 0 ? Int(checkPointPosition.floor) : Int(checkPointPosition.floor + 1)
            if currentFloor == floor,
               let latitudeNode = Double(checkPointPosition.latitude),
               let longitudeNode = Double(checkPointPosition.longitude) {

                for landmark in landmarks {
                    if landmark.floor == floor,
                       checkPointPosition.title == landmark.title {
                        let linkModel = LandmarkModel(id: landmark.id,
                                                      nodeId: landmark.id,
                                                      groundFloor: Int(checkPointPosition.floor),
                                                      title: landmark.title,
                                                      titlePron: landmark.titlePron,
                                                      titleEn: landmark.titleEn,
                                                      nodeLocation: HLPLocation(lat: latitudeNode,
                                                                                lng: longitudeNode),
                                                      spotLocation: landmark.spotLocation)
                        linkModel.isExhibitionZone = landmark.isExhibitionZone
                        self.appendItem(model: linkModel)
                        break
                    }
                }
            }
        }
    }

    private func appendItem(model: LandmarkModel) {
        if !model.title.contains("ASIMO") {
            self.items.append(model)
        }
    }

    /// サーバデータ初期化
    private func initHLPDirectory() {
        if initFlag { return }
        guard landmarks.isEmpty,
              let navDataStore = NavDataStore.shared(),
              let directory = navDataStore.directory(),
              let destinations = navDataStore.destinations() else { return }

        initLandmark(destinations: destinations)
        appendAdditionalLocation()
        initHLPDirectorySection(sections: directory.sections)
        updateLandmark()
        updateSectionData()
        initFloorPlan()
        
        initFlag = true
    }

    private func initLandmark(destinations: [Any]) {
        for landmark in destinations {
            if let landmark = landmark as? HLPLandmark,
               let id = landmark.properties[PROPKEY_FACILITY_ID] as? String,
               let coordinates = landmark.geometry.coordinates,
               let latitude = coordinates[1] as? Double,
               let longitude = coordinates[0] as? Double {
                let titleEn = landmark.properties[PROPKEY_NAME] as? String
                let model = LandmarkModel(id: id,
                                          nodeId:  landmark.nodeID,
                                          groundFloor: Int(landmark.nodeHeight),
                                          title: landmark.name,
                                          titlePron: landmark.namePron,
                                          titleEn: titleEn,
                                          nodeLocation: landmark.nodeLocation,
                                          spotLocation: HLPLocation(lat: latitude, lng: longitude))
                self.landmarks.append(model)
            }
        }
    }

    private func appendAdditionalLocation() {
        for additionalLocation in additionalLocations {
            if let latitude = Double(additionalLocation.latitude),
               let longitude = Double(additionalLocation.longitude) {
                let model = LandmarkModel(id: additionalLocation.id,
                                          nodeId: additionalLocation.nodeId,
                                          groundFloor: additionalLocation.floor,
                                          title: additionalLocation.title,
                                          titlePron: additionalLocation.titlePron,
                                          titleEn: additionalLocation.titleEn,
                                          nodeLocation: HLPLocation(lat: latitude, lng: longitude),
                                          spotLocation: HLPLocation(lat: latitude, lng: longitude),
                                          checkPointOnly: additionalLocation.checkPointOnly ?? false)
                self.landmarks.append(model)
            }
        }
    }
    
    private func initHLPDirectorySection(sections: [HLPDirectorySection]) {
        for section in sections {
            for item in section.items {
                if let content = item.content {
                    initHLPDirectorySection(sections: content.sections)
                } else {
                    let toilet = item.toilet.rawValue
                    if toilet != HLPToiletTypeNone.rawValue {
                        let sectionItem = HLPSectionModel(nodeId: item.nodeID,
                                                          title: item.title,
                                                          titlePron: item.titlePron,
                                                          subtitle: item.subtitle,
                                                          subtitlePron: item.subtitlePron,
                                                          toilet: Int(toilet))
                        self.sectionItems.append(sectionItem)
                    }
                }
            }
        }
    }

    private func updateSectionData() {
        for landmark in landmarks {
            if landmark.title.isEmpty {
                for sectionItem in sectionItems {
                    if landmark.nodeId == sectionItem.nodeId,
                       !sectionItem.title.isEmpty,
                       let titlePron = sectionItem.titlePron {
                        landmark.titleUpdate(title: sectionItem.title, titlePron: titlePron, titleEn: getRestRoomText(title: sectionItem.title))
                        sectionItem.floor = landmark.floor
                        sectionItem.isExhibitionZone = landmark.isExhibitionZone
                        break
                    }
                }
            }
        }
    }

    func getRestList() -> [HLPSectionModel] {
        initHLPDirectory()

        var restList: [HLPSectionModel] = []
        for item in sectionItems where item.floor != nil  {
            restList.append(item)
        }
        return restList
    }

    private func getRestRoomText(title: String) -> String {
        
        if title.contains("女性用多機能トイレ") {
            return NSLocalizedString("FOR_FEMALEFOR_DISABLEDRESTROOM", tableName: "BlindView", comment: "")
        } else if title.contains("男性用多機能トイレ") {
            return NSLocalizedString("FOR_MALEFOR_DISABLEDRESTROOM", tableName: "BlindView", comment: "")
        } else if title.contains("多機能トイレ") {
            return NSLocalizedString("FOR_DISABLEDRESTROOM", tableName: "BlindView", comment: "")
        } else if title.contains("女性用トイレ") {
            return NSLocalizedString("FOR_FEMALERESTROOM", tableName: "BlindView", comment: "")
        } else if title.contains("男性用トイレ") {
            return NSLocalizedString("FOR_MALERESTROOM", tableName: "BlindView", comment: "")
        } else if title.contains("トイレ") {
            return NSLocalizedString("RESTROOM", tableName: "BlindView", comment: "")
        }

        return title
    }

    private func updateLandmark() {
        for landmark in landmarks {
            landmark.isExhibitionZone = isExhibitionZone(current: landmark.nodeLocation)
        }
    }

    private func locationChanged(current: HLPLocation) {
        if !UserDefaults.standard.bool(forKey: "isVoiceGuideOn") {
            return
        }

        let now = Date().timeIntervalSince1970
        if !current.lat.isNaN && !current.lng.isNaN && (locationChangedTime + checkTime < now) {

            if checkLocation == nil {
                locationChangedTime = now
                checkLocation = current
                return
            }

            let distance = current.distance(to: checkLocation)
            if distance < checkDistance {
                return
            }
            
            guard let checkLocation = checkLocation else { return }
            let checkPoint = CGPoint(x: checkLocation.lat, y: checkLocation.lng)
            let currentPoint = CGPoint(x: current.lat, y: current.lng)
            let vector = Line(from: checkPoint, to: currentPoint)
            let isExhibitionZone = isExhibitionZone(current: current)
            locationChangedTime = now
            self.checkLocation = current

            for item in self.items {
                item.distance = current.distance(to: item.nodeLocation)
            }

            var sortItems = self.items.filter({ $0.distance <= nearestFront })
            sortItems.sort(by: { $0.distance < $1.distance})
            
            var positionModels: [PositionModel] = []

            for item in sortItems where item.isExhibitionZone == isExhibitionZone {
                if self.nearestItems.first(where: {$0?.id == item.id }) == nil,
                   positionModels.first(where: {$0.id == item.id }) == nil {
                    let destination = CGPoint(x: item.spotLocation.lat, y: item.spotLocation.lng)
                    let lineSegment = Line(from: currentPoint, to: destination)
                    
                    let sita = Line.angle(vector, lineSegment)
                    let sitaPi = sita * 180.0 / Double.pi
                    
                    if sitaPi < angleFront ||
                        sitaPi < angleSide && item.distance < nearestSide ||
                        sitaPi < angleRear && item.distance < nearestRear {

                        let positionModel = PositionModel(id: item.id, titlePron: item.titlePron, titleEn: item.titleEn)
                        positionModel.distance = item.distance
                        let isRightDirection = Line.isRightDirection(vector, point: destination)
                        positionModel.angle = sitaPi * (isRightDirection ? -1 : 1)
                        
                        positionModel.longitude = item.spotLocation.lng
                        positionModel.latitude = item.spotLocation.lat
                        positionModels.append(positionModel)
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
                    var titlePron = item.titlePron
                    if lang != "ja",
                       let titleEn = item.titleEn {
                        titlePron = titleEn
                    }

                    let speakText = String(format: NSLocalizedString(localizeKey, tableName: "BlindView", comment: ""), titlePron)
                    self.speakTexts.append(speakText)

                    let dateFormatter = DateFormatter()
                    dateFormatter.calendar = Calendar(identifier: .gregorian)
                    dateFormatter.locale = Locale(identifier: "ja_JP")
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
                    let dateString = dateFormatter.string(from: Date())
                    self.writeData("\(dateString), \(current.lng), \(current.lat), , , , , ,\(speakText), \(item.distance), \(item.angle), \(item.longitude), \(item.latitude)\n")
                }
            }
            
            if positionModels.count > 0 {
                self.dequeueSpeak()
            }
        }
    }
    
    func nearLocationSpeak(current: HLPLocation) {
        if let model = nearLocation(current: current) {
            if UserDefaults.standard.bool(forKey: "isVoiceGuideOn") {
                self.speakTexts.append(String(format: NSLocalizedString("Near", tableName: "BlindView", comment: ""), model.accessibility))
                self.dequeueSpeak()
            }
        }
    }

    func nearLocation(current: HLPLocation) -> AccessibilityModel? {
        if !current.lat.isNaN && !current.lng.isNaN {

            for item in self.items {
                item.distance = current.distance(to: item.nodeLocation)
            }
            
            var sortItems = self.items.filter({ $0.distance <= nearestFront })
            sortItems.sort(by: { $0.distance < $1.distance})
            
            if let sortItem = sortItems.first {
                let titlePron = sortItem.titlePron
                if lang != "ja",
                   let titleEn = sortItem.titleEn {
                    return AccessibilityModel(string: titleEn, accessibility: titleEn)
                }
                return AccessibilityModel(string: sortItem.title, accessibility: titlePron)
            }
        }
        return nil
    }

    func isExhibitionZone(current: HLPLocation) -> Bool {
        let startPoint = CGPoint(x: 139.77607, y: 35.61905)
        let endPoint = CGPoint(x: 139.7772, y: 35.61963)

        let vector = Line(from: startPoint, to: endPoint)
        let currentPoint = CGPoint(x: current.lng, y: current.lat)

        let isExhibitionZone = Line.isRightDirection(vector, point: currentPoint)
        
        return isExhibitionZone
    }
    
    func isSymbolZone(current: HLPLocation) -> Bool {
        let startPoint = CGPoint(x: 139.77693, y: 35.619495)
        let endPoint = CGPoint(x: 139.77711, y: 35.61927)

        let vector = Line(from: startPoint, to: endPoint)
        let currentPoint = CGPoint(x: current.lng, y: current.lat)

        let isSymbolZone = !Line.isRightDirection(vector, point: currentPoint)

        return isSymbolZone
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

extension AudioGuideManager {

    func initGuidePosition() {
        if let guidePosition = MiraikanUtil.readJSONFile(filename: "GuidePosition",
                                                         type: [GuidePositionModel].self) as? [GuidePositionModel] {
            self.guidePositions = guidePosition
        }
    }

    func getGuidePosition(title: String, floor: Int) -> GuidePositionModel? {
        for guidePosition in self.guidePositions {
            let guidePositionFloor = guidePosition.floor < 0 ? guidePosition.floor : guidePosition.floor + 1
            if title == guidePosition.title,
               floor == guidePositionFloor {
                return guidePosition
            }
        }
        return nil
    }

    func initCheckPointPosition() {
        if let checkPointPositions = MiraikanUtil.readJSONFile(filename: "CheckPointPosition",
                                                         type: [GuidePositionModel].self) as? [GuidePositionModel] {
            self.checkPointPositions = checkPointPositions
        }
    }

    func initAdditionalLocation() {
        if let additionalLocations = MiraikanUtil.readJSONFile(filename: "AdditionalLocation",
                                                         type: [AdditionalLocationModel].self) as? [AdditionalLocationModel] {
            self.additionalLocations = additionalLocations
        }
    }

    func initFloorPlan() {
        if let floorPlans = MiraikanUtil.readJSONFile(filename: "FloorPlan",
                                                         type: [FloorPlanModel].self) as? [FloorPlanModel] {
            self.floorPlans = floorPlans
        }
    }
}

extension AudioGuideManager {

    func setFilePath(_ writeLine: String) {
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
            filePath = dir.appendingPathComponent("audioGuide\(dateString).csv")
            guard let filePath = filePath else { return }
            if FileManager.default.createFile(
                            atPath: filePath.path,
                            contents: nil,
                            attributes: nil
                            )
            {
                if let file = FileHandle(forWritingAtPath: filePath.path),
                   let data = writeLine.data(using: .utf8) {
                    file.seekToEndOfFile()
                    file.write(data)
                }
            }
        }
    }
    
    func writeData(_ writeLine: String) {
        if !UserDefaults.standard.bool(forKey: "DebugMode") {
            return
        }

        if let filePath = filePath {
            if let file = FileHandle(forWritingAtPath: filePath.path),
               let data = writeLine.data(using: .utf8) {
                file.seekToEndOfFile()
                file.write(data)
            }
        } else {
            setFilePath(writeLine)
        }
    }
}
