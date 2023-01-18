//
//
//  DistanceCheckViewController.swift
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

/**
 Home and initial settings
 */
class DistanceCheckViewController: BaseController {

    private let distanceCheckView = DistanceCheckView()

    private var temporaryFloor: CGFloat = 0
    private var currentFloor: CGFloat = 0
    private var continueFloorCount: CGFloat = 0

    init(title: String) {
        super.init(distanceCheckView, title: title)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let center = NotificationCenter.default
        center.removeObserver(self)
        center.addObserver(self,
                           selector: #selector(type(of: self).locationChanged(note:)),
                           name: NSNotification.Name("nav_location_changed_notification"),
                           object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        let center = NotificationCenter.default
        center.removeObserver(self)
    }

    @objc private func locationChanged(note: Notification) {
        
        guard let userInfo = note.userInfo,
              let current = userInfo["current"] as? HLPLocation else {
          return
        }

        if (temporaryFloor == current.floor + 1) {
            continueFloorCount += 1
        } else {
            continueFloorCount = 0;
        }
        temporaryFloor = current.floor + 1

        if continueFloorCount > 20 &&
            currentFloor != temporaryFloor {
            currentFloor = temporaryFloor
            distanceCheckView.floorChanged(floor: Int(currentFloor))
        }
        
        distanceCheckView.locationChanged(current: current)
    }
}
