//
//  StrUtil.swift
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

class StrUtil: NSObject {

    // 距離を簡略化数値にする。1m以下はcmで四捨五入の数値
    static public func getMeterString(distance: Double) -> String {
        if distance < 0.95 {
            let distance = Int(round((distance + 0.05) * 10) * 10)
            if distance == 100 {
                return String(format: "%dメートル", distance / 100)
            } else {
                return String(format: "%dセンチメートル", distance)
            }
        } else {
            let distance = Int(round(distance))
            return String(format: "%dメートル", distance)
        }
    }

    // 上を正面で角度0度、左回りに角度が加算される時の方角文字列
//    static public func getDirectionString(angle: Float) -> PhonationModel {
//        let phonationModel = PhonationModel()
//        let HourAngle = Float(360 / 24)
//
//        if HourAngle < angle && angle <= HourAngle * 3 {
//            phonationModel.setUp(string: "11時の方向", phonation: "11時の方向")
//        } else if HourAngle * 3 < angle && angle <= HourAngle * 5 {
//            phonationModel.setUp(string: "10時の方向", phonation: "10時の方向")
//        } else if HourAngle * 5 < angle && angle <= HourAngle * 7 {
//            phonationModel.setUp(string: "左方向", phonation: "左方向")
//        } else if HourAngle * 7 < angle && angle <= HourAngle * 9 {
//            phonationModel.setUp(string: "8時の方向", phonation: "8時の方向")
//        } else if HourAngle * 9 < angle && angle <= HourAngle * 11 {
//            phonationModel.setUp(string: "7時の方向", phonation: "7時の方向")
//        } else if HourAngle * 11 < angle && angle <= HourAngle * 13 {
//            phonationModel.setUp(string: "後ろ", phonation: "後ろ")
//        } else if HourAngle * 13 < angle && angle <= HourAngle * 15 {
//            phonationModel.setUp(string: "5時の方向", phonation: "5時の方向")
//        } else if HourAngle * 15 < angle && angle <= HourAngle * 17 {
//            phonationModel.setUp(string: "4時の方向", phonation: "4時の方向")
//        } else if HourAngle * 17 < angle && angle <= HourAngle * 19 {
//            phonationModel.setUp(string: "右方向", phonation: "右方向")
//        } else if HourAngle * 19 < angle && angle <= HourAngle * 21 {
//            phonationModel.setUp(string: "2時の方向", phonation: "2時の方向")
//        } else if HourAngle * 21 < angle && angle <= HourAngle * 23 {
//            phonationModel.setUp(string: "1時の方向", phonation: "1時の方向")
//        } else {
//            phonationModel.setUp(string: "正面", phonation: "正面")
//        }
//        return phonationModel
//    }

    static public func getDirectionString(angle: Double) -> PhonationModel {
        let phonationModel = PhonationModel()
        let HourAngle = Double(360 / 24)

        if HourAngle < angle && angle <= HourAngle * 3 {
            phonationModel.setUp(string: "やや左方向", phonation: "やや左方向")
        } else if HourAngle * 3 < angle && angle <= HourAngle * 5 {
            phonationModel.setUp(string: "斜め左方向", phonation: "斜め左方向")
        } else if HourAngle * 5 < angle && angle <= HourAngle * 7 {
            phonationModel.setUp(string: "左方向", phonation: "左方向")
        } else if HourAngle * 7 < angle && angle <= HourAngle * 9 {
            phonationModel.setUp(string: "左斜め後ろ方向", phonation: "左斜め後ろ方向")
        } else if HourAngle * 9 < angle && angle <= HourAngle * 11 {
            phonationModel.setUp(string: "左斜め後ろ方向", phonation: "左斜め後ろ方向")
        } else if HourAngle * 11 < angle && angle <= HourAngle * 13 {
            phonationModel.setUp(string: "後ろ", phonation: "後ろ")
        } else if HourAngle * 13 < angle && angle <= HourAngle * 15 {
            phonationModel.setUp(string: "右斜め後ろ方向", phonation: "右斜め後ろ方向")
        } else if HourAngle * 15 < angle && angle <= HourAngle * 17 {
            phonationModel.setUp(string: "右斜め後ろ方向", phonation: "右斜め後ろ方向")
        } else if HourAngle * 17 < angle && angle <= HourAngle * 19 {
            phonationModel.setUp(string: "右方向", phonation: "右方向")
        } else if HourAngle * 19 < angle && angle <= HourAngle * 21 {
            phonationModel.setUp(string: "斜め右方向", phonation: "斜め右方向")
        } else if HourAngle * 21 < angle && angle <= HourAngle * 23 {
            phonationModel.setUp(string: "やや右方向", phonation: "やや右方向")
        } else {
            phonationModel.setUp(string: "正面", phonation: "正面")
        }
        return phonationModel
    }
}
