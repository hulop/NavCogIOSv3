//
//  ArManager.swift
//  NavCogMiraikan
//
/*******************************************************************************
 * Copyright (c) 2023 © Miraikan - The National Museum of Emerging Science and Innovation
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
final public class ArManager: NSObject {
    
    public static let shared = ArManager()

    var arFrameSize: CGSize?

    private var guideSoundTime: Double = 0
    private var markerCenterFlag = false

    private var checkMarkerTime: Double = 0
    private var flatGuideTime: Double = 0

    private let widthBaseRatio: Double = 100
    private let widthMinCenterRatio: Double = 10
    private let widthMaxCenterRatio: Double = 25
    private let widthMinMarginRatio: Double = 20
    private let widthMaxMarginRatio: Double = 40

    private let longRange: Double = 10
    
    private override init() {
        super.init()
    }

    func setArFrameSize(arFrameSize: CGSize?) {
        self.arFrameSize = arFrameSize
    }
    
    func setSpeakStr(arUcoModel: ArUcoModel, transform: MarkerWorldTransform, isDebug: Bool = false) -> PhonationModel {
        
        let ratio = ArUcoManager.shared.getMarkerSizeRatio(arUcoModel: arUcoModel)
        let distance = Double(transform.distance) * ratio
        let horizontalDistance = Double(transform.horizontalDistance) * ratio
        let direction = Double(transform.yaw)
        let meterString = StrUtil.getMeterString(distance: distance)

//        NSLog("id: \(transform.arucoId), ratio: \(ratio), distance: \(distance), horizontalDistance: \(horizontalDistance),  x: \(direction)")

        let phonationModel = PhonationModel()

        if let guideToHere = arUcoModel.guideToHere,
           guideToHere.isDistance(distance) || isDebug {
            setPhonation(phonationModel, strParam: meterString, guidance: guideToHere)
        }
        
        if let description = arUcoModel.description {
            if description.isDistance(distance) {
                if let descriptionTitle = arUcoModel.descriptionTitle,
                   descriptionTitle.isDistance(distance) {
                    setPhonation(phonationModel, strParam: meterString, guidance: descriptionTitle)
                }
                setPhonation(phonationModel, strParam: meterString, guidance: description)
            }

            if let nextGuide = arUcoModel.nextGuide,
               nextGuide.isDistance(distance) || isDebug {
                setPhonation(phonationModel, strParam: meterString, guidance: nextGuide)
            }

            if let guideFromHere = arUcoModel.guideFromHere,
               guideFromHere.isDistance(distance) || isDebug {
                setPhonation(phonationModel, strParam: meterString, guidance: guideFromHere)
            }
        }

        if !isGuideMarker() {
            if let flatGuideList = arUcoModel.flatGuide,
               distance < 3.0 {
                if horizontalDistance > 0.9 {
                    
                    let now = Date().timeIntervalSince1970
                    var msg = ""
                    if let arFrameSize = arFrameSize {
                        if arFrameSize.height * 2 / 5 > transform.intersection.y {
                            msg += NSLocalizedString("Turn to the right a little", comment: "")
                            msg += NSLocalizedString("PERIOD", comment: "")
                        } else if arFrameSize.height * 3 / 5 < transform.intersection.y {
                            msg += NSLocalizedString("Turn to the left a little", comment: "")
                            msg += NSLocalizedString("PERIOD", comment: "")
                        } else {
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                        msg += NSLocalizedString("please proceed slowly.", comment: "")
                    }
                    
                    if flatGuideTime + 5.0 < Date().timeIntervalSince1970 {
                        phonationModel.append(str: msg, phon: msg, isDelimiter: false)
                        flatGuideTime = now
                    }
                } else {
                    for flatGuide in flatGuideList {
                        if let targetDirection = flatGuide.direction {
                            let directionStr = getDirectionString(direction: targetDirection, currentDirection: direction)
                            phonationModel.append(str: directionStr.string, phon: directionStr.phonation, isDelimiter: false)
                            setPhonation(phonationModel, guidance: flatGuide)
                        }
                    }
                }
            }
        }
        return phonationModel
    }

    // 地面AR
    func setFlatSoundEffect(arUcoModel: ArUcoModel, transform: MarkerWorldTransform) {
        let ratio = ArUcoManager.shared.getMarkerSizeRatio(arUcoModel: arUcoModel)
        let distance = Double(transform.distance) * ratio

        if let _ = arUcoModel.flatGuide,
           distance < 3.0 {

            guard let arFrameSize = arFrameSize else {
                return
            }

            var rate: Double = -1
            var pan: Double = 0
            var interval: Double = 0

            // 中央判定
            let centerRatio = (widthMaxCenterRatio - widthMinCenterRatio) / longRange * distance + widthMinCenterRatio
            let minCenterRange = (widthBaseRatio - centerRatio) / 2
            let maxCenterRange = widthBaseRatio - minCenterRange
            
            // 中央近く判定
            let marginRatio = (widthMaxMarginRatio - widthMinMarginRatio) / longRange * distance + widthMinMarginRatio
            let minMarginRange = (widthBaseRatio - marginRatio) / 2
            let maxnMarginRange = widthBaseRatio - minMarginRange

            if arFrameSize.height * minCenterRange / widthBaseRatio  < transform.intersection.y &&
                arFrameSize.height * maxCenterRange / widthBaseRatio > transform.intersection.y {
                // 中央
            } else if arFrameSize.height * minMarginRange / widthBaseRatio < transform.intersection.y &&
                    arFrameSize.height * maxnMarginRange / widthBaseRatio > transform.intersection.y {
                // 中央近く高速音
                rate = 2
                pan = 0.3
                interval = 0
            } else {
                
                let width = arFrameSize.height / 2
                let baseWidth: Double = arFrameSize.height * minMarginRange / widthBaseRatio
                if width < transform.intersection.y {
                    pan = Double(transform.intersection.y - width) / baseWidth
                } else {
                    pan = Double(width - transform.intersection.y) / baseWidth
                }
                
                if pan < 0.0 { pan = 0.0 }
                if pan > 1.0 { pan = 1.0 }
                interval = pan * 0.8
                rate = 2 - pan * 0.3
            }

            if rate > 2.0 { rate = 2.0 }
            if interval > 2.0 { interval = 2.0 }

            // right or left
            if arFrameSize.height / 2 < transform.intersection.y {
                pan = -1 * pan
            }

            if rate > 0 &&
                !AudioManager.shared.isSoundEffect {
                AudioManager.shared.SoundEffect(sound: "SoundEffect02", rate: rate, pan: pan, interval: interval)
            }
        }
    }
    
    func setSoundEffect(arUcoModel: ArUcoModel, transform: MarkerWorldTransform) {
        guard let arFrameSize = arFrameSize else {
            return
        }

        let ratio = ArUcoManager.shared.getMarkerSizeRatio(arUcoModel: arUcoModel)
        let distance = Double(transform.distance) * ratio

        if distance < 1.2 {
            var phonation = arUcoModel.titlePron
            phonation += NSLocalizedString("It is the entrance.", comment: "")
            phonation += NSLocalizedString("Point your smartphone camera at the ground.", comment: "")
            phonation += NSLocalizedString("While facing the ground, turn left and right slowly and check the following directions.", comment: "")
            phonation += NSLocalizedString("When facing the ground, please proceed after reaching a position that guides you to the front.", comment: "")
            
            AudioManager.shared.addGuide(text: phonation, id: arUcoModel.id)
            return
        }

        var rate: Double = -1
        var pan: Double = 0
        var interval: Double = 0

        let now = Date().timeIntervalSince1970
        checkMarkerTime = now

        // 中央判定
        let centerRatio = (widthMaxCenterRatio - widthMinCenterRatio) / longRange * distance + widthMinCenterRatio
        let minCenterRange = (widthBaseRatio - centerRatio) / 2
        let maxCenterRange = widthBaseRatio - minCenterRange
        
        // 中央近く判定
        let marginRatio = (widthMaxMarginRatio - widthMinMarginRatio) / longRange * distance + widthMinMarginRatio
        let minMarginRange = (widthBaseRatio - marginRatio) / 2
        let maxnMarginRange = widthBaseRatio - minMarginRange

        if arFrameSize.height * minCenterRange / widthBaseRatio  < transform.intersection.y &&
            arFrameSize.height * maxCenterRange / widthBaseRatio > transform.intersection.y {
            // 中央
            UISelectionFeedbackGenerator().selectionChanged()

            if !markerCenterFlag &&
                !AudioManager.shared.isSoundEffect {
                AudioManager.shared.SoundEffect(sound: "SoundEffect01", rate: 2, pan: 0, interval: 0)
                guideSoundTime = now
                markerCenterFlag = true
            } else if guideSoundTime != 0 &&
                        guideSoundTime + 1.0 < now &&
                        !AudioManager.shared.isStack() {
                guideSoundTime = now + 10.0
                markerCenterFlag = true

                let meterString = StrUtil.getMeterString(distance: distance)
                let phonation = arUcoModel.titlePron + NSLocalizedString("PERIOD", comment: "") + NSLocalizedString("to the entrance", comment: "") + meterString
                AudioManager.shared.addGuide(text: phonation, id: arUcoModel.id)
            }
            return
        } else if arFrameSize.height * minMarginRange / widthBaseRatio < transform.intersection.y &&
                arFrameSize.height * maxnMarginRange / widthBaseRatio > transform.intersection.y {
            // 中央近く高速音
            rate = 2
            pan = 0.3
            interval = 0
        } else {
            
            let width = arFrameSize.height / 2
            let baseWidth: Double = arFrameSize.height * minMarginRange / widthBaseRatio
            if width < transform.intersection.y {
                pan = Double(transform.intersection.y - width) / baseWidth
            } else {
                pan = Double(width - transform.intersection.y) / baseWidth
            }
            
            if pan < 0.0 { pan = 0.0 }
            if pan > 1.0 { pan = 1.0 }
            interval = pan * 0.8
            rate = 2 - pan * 0.3
        }

        if rate > 2.0 { rate = 2.0 }
        if interval > 2.0 { interval = 2.0 }

        // right or left
        if arFrameSize.height / 2 < transform.intersection.y {
            pan = -1 * pan
        }

        if rate > 0 &&
            !AudioManager.shared.isSoundEffect {
            AudioManager.shared.SoundEffect(sound: "SoundEffect02", rate: rate, pan: pan, interval: interval)
            markerCenterFlag = false
            guideSoundTime = 0
        }
    }

    private func isGuideMarker() -> Bool {
        if checkMarkerTime + 1.0 > Date().timeIntervalSince1970 {
            return true
        }

        return false
    }

    private func getDirectionString(direction: Double, currentDirection: Double) -> PhonationModel {
        var angle = direction + currentDirection - 90
        angle = angle.remainder(dividingBy: 360.0)
        angle = angle < 0 ? angle + 360 : angle
        return StrUtil.getDirectionString(angle: angle)
    }

    private func setPhonation(_ phonation: PhonationModel, strParam: String? = nil, guidance: GuidanceModel) {
        if NSLocale.preferredLanguages.first?.components(separatedBy: "-").first == "ja" {
            if let strParam = strParam {
                phonation.append(str: String(format: guidance.message, strParam), phon: String(format: guidance.messagePron, strParam))
            } else {
                phonation.append(str: guidance.message, phon: guidance.messagePron)
            }
        } else {
            if let strParam = strParam {
                phonation.append(str: String(format: guidance.messageEn, strParam), phon: String(format: guidance.messagePron, strParam))
            } else {
                phonation.append(str: guidance.messageEn)
            }
        }
    }
}
