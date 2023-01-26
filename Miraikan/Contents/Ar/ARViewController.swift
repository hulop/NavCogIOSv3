//
//  ARViewController.swift
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

import UIKit
import Foundation
import SceneKit
import ARKit

class ARViewController: UIViewController {

    var sceneView: ARSCNView!

    var mutexlock = false
    var arFrameSize: CGSize?

    private var locationChangedTime = Date().timeIntervalSince1970

    private let checkTime: Double = 1

    private var shakeDate: Date?

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView = ARSCNView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height))
        self.view.addSubview(sceneView)
        
        sceneView.delegate = self
        sceneView.session.delegate = self

        let scene = SCNScene()
        sceneView.scene = scene

        _ = ArUcoManager.shared
        
        AudioManager.shared.setupInitialize()
        AudioManager.shared.delegate = self

        // ジャスチャー
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTapGesture)

        // シェイク
        becomeFirstResponder()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let array = ARWorldTrackingConfiguration.supportedVideoFormats
        let videoFormats = array.first
        arFrameSize = videoFormats?.imageResolution
        ArManager.shared.setArFrameSize(arFrameSize: videoFormats?.imageResolution)

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // スリープさせない
        UIApplication.shared.isIdleTimerDisabled = true

        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
//        configuration.isLightEstimationEnabled = true
        configuration.worldAlignment = .gravity

        // Nodeに無指向性の光を追加するオプション
//        sceneView.autoenablesDefaultLighting = true
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Pause the view's session
        sceneView.session.pause()
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            shakeDate = Date()
        }
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            if let shakeDate = shakeDate {
                let diff = Date().timeIntervalSince(shakeDate)
                if diff > 0 && diff < 2 {
                    AudioManager.shared.repeatSpeak()
                }
            }
        }
    }

    override func motionCancelled(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            shakeDate = nil
        }
    }
}

extension ARViewController {

    @objc func doubleTap(_ gesture: UITapGestureRecognizer) {
        AudioManager.shared.stop()
    }

    @IBAction func tapAction(_ sender: Any) {
        if AudioManager.shared.isPlaying {
            AudioManager.shared.stop()
        }
    }
    
    private func updateArContent(transforms: Array<MarkerWorldTransform>) {

        let sortedTransforms = transforms.sorted { $0.distance < $1.distance }

        for transform in sortedTransforms {
            for arUcoModel in ArUcoManager.shared.arUcoList {
//                NSLog("yaw: \(transform.yaw), pitch: \(transform.pitch), roll: \(transform.roll),       x: \(transform.x), y: \(transform.y), z: \(transform.z), horizontalDistance: \(transform.horizontalDistance)")
                if arUcoModel.id == transform.arucoId {
                    activeArUcoData(arUcoModel: arUcoModel, transform: transform)
                    break
                }
            }
        }
    }

    private func activeArUcoData(arUcoModel: ArUcoModel, transform: MarkerWorldTransform) {

        if let markerPoint = arUcoModel.markerPoint,
           markerPoint {
            ArManager.shared.setSoundEffect(arUcoModel: arUcoModel, transform: transform)
        } else if !AudioManager.shared.isStack() {
            setAudioData(arUcoModel: arUcoModel, transform: transform)
        }
    }

    private func setAudioData(arUcoModel: ArUcoModel, transform: MarkerWorldTransform) {
        
        ArManager.shared.setFlatSoundEffect(arUcoModel: arUcoModel, transform: transform)

        let now = Date().timeIntervalSince1970
        if (locationChangedTime + checkTime > now) {
            return
        }

        let phonationModel = ArManager.shared.setSpeakStr(arUcoModel: arUcoModel, transform: transform)
        if !phonationModel.phonation.isEmpty {
            AudioManager.shared.addGuide(text: phonationModel.phonation, id: arUcoModel.id)
            locationChangedTime = now
        }
    }

    func setNotification() {
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(voiceOverNotification),
                           name: UIAccessibility.voiceOverStatusDidChangeNotification,
                           object: nil)
    }

    @objc private func voiceOverNotification() {
    }
}

// MARK: - ARSessionDelegate
extension ARViewController: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {

        if self.mutexlock {
            return
        }

        self.mutexlock = true
        let pixelBuffer = frame.capturedImage

        let transMatrixArray = OpenCVWrapper.estimatePose(pixelBuffer,
                                                          withIntrinsics: frame.camera.intrinsics,
                                                          andMarkerSize: ArUcoManager.shared.ArucoMarkerSize) as! Array<MarkerWorldTransform>
        if(transMatrixArray.count == 0) {
            DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 0.2, execute: {
                self.mutexlock = false
            })
            return
        }

        DispatchQueue.main.async(execute: {
            self.updateArContent(transforms: transMatrixArray)
            DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 0.25, execute: {
                self.mutexlock = false
            })
        })
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
    }
}

// MARK: - ARSessionObserver
extension ARViewController: ARSessionObserver {
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
    }
}

// MARK: - ARSCNViewDelegate
extension ARViewController: ARSCNViewDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }

    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
}

// MARK: - AudioManagerDelegate
extension ARViewController: AudioManagerDelegate {
    func speakingMessage(message: String) {
    }
}
