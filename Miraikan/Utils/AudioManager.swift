//
//  AudioManager.swift
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
import AVFoundation
import AudioToolbox
import AVKit

protocol AudioManagerDelegate {
    func speakingMessage(message: String)
}

// Singleton
final public class AudioManager: NSObject {
    
    var delegate: AudioManagerDelegate?
    
    private let tts = DefaultTTS()
    private(set) var isPlaying = false
    private(set) var isSoundEffect = false
    private var cacheTexts = [String](repeating: "", count: 3)
    private var ids = [Int?](repeating: nil, count: 3)
    
    private var voiceList = [VoiceModel?](repeating: nil, count: 3)
    
    private var speakTexts: [String] = []
    private var repeatText: String?
    private var player: AVAudioPlayer?

    private var initializeTime: Double = 0

    private var soundEffectTime: Double = 0
    private var intervalTime: Double = 0

    @objc dynamic var isDisplay = true
    private var isActive = true

    private let checkTime: Double = 1

    private var filePath: URL?
    private var lang = ""

    private override init() {
        super.init()
        lang = NSLocalizedString("lang", comment: "")
        initializeTime = Date().timeIntervalSince1970
        
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(voiceOverNotification),
                           name: UIAccessibility.voiceOverStatusDidChangeNotification,
                           object: nil)
    }

    public static let shared = AudioManager()

    func setupInitialize() {
        
        var msg = NSLocalizedString("If you point your smartphone's camera at the front, you'll get an explanation of the exhibition, and if you point it at the ground, you'll be guided through the route.", comment: "")
        msg += NSLocalizedString("Audio stops when you double tap the screen.", comment: "")
        self.speakTexts.append(msg)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            _ = self.dequeueSpeak()
        }
    }

    func setupStartingPoint() {
        self.stop()
        self.speakTexts.append(NSLocalizedString("With your smartphone's camera facing forward and upwards, slowly turn left and right, looking for sound guidance.", comment: ""))

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            _ = self.dequeueSpeak()
        }
    }

    func isDisplayButton(_ isDisplay: Bool) {
        self.isDisplay = isDisplay
    }

    func isActive(_ isActive: Bool) {
        self.speakTexts.removeAll()
        self.isActive = isActive
    }

    func isStack() -> Bool {
        !self.speakTexts.isEmpty
    }

    func addGuide(text: String, id: Int? = nil, priority: Int = 10) {
        
        if let voiceData = self.voiceList.first,
           let voicePriority = voiceData?.priority,
           voicePriority < priority {
            self.voiceList.removeAll()
        } else if self.isPlaying {
            return
        }

        if !text.isEmpty {
            self.voiceList.removeFirst()
            self.voiceList.append(VoiceModel(id: id, message: text, priority: priority))
            self.speakTexts.append(text)
            _ = self.dequeueSpeak()
        }
    }

    func stop() {
        tts.stop(true)
        self.isPlaying = false
    }

    func repeatSpeak() {
        if !self.isPlaying,
           let repeatText = repeatText {
            self.play(text: repeatText)
        }
    }

    func forcedSpeak(text: String) {
        self.stop()
        self.play(text: text)
    }

    private func play(text: String) {
        if self.isPlaying { return }

        self.isPlaying = true
        tts.speak(text, callback: { [weak self] in
            guard let self = self else { return }
            self.isPlaying = false
        })

        if let delegate = delegate {
            delegate.speakingMessage(message: text)
        }
    }

    private func dequeueSpeak() -> Bool {
        if self.isPlaying { return false }
//        if UIAccessibility.isVoiceOverRunning { return false }
        if let text = speakTexts.first {
            repeatText = text
            self.play(text: text)
            self.speakTexts.removeFirst()
        }
        return true
    }

    func SoundEffect(sound: String, rate: Double, pan: Double, interval: Double) {
//        NSLog("rate: \(rate),  pan: \(pan),  interval: \(interval)" )
        if self.isSoundEffect { return }
        let now = Date().timeIntervalSince1970
        if (soundEffectTime != 0 &&
            soundEffectTime + intervalTime > now) {
            return
        }
        intervalTime = interval

        soundEffectTime = now
        self.isSoundEffect = true

        if let soundURL = Bundle.main.url(forResource: sound, withExtension: "mp3") {
            do {
                player = try AVAudioPlayer(contentsOf: soundURL)
                if let player = player {
                    player.delegate = self
                    player.enableRate = true
                    player.rate = Float(rate)
                    player.pan = Float(pan)
                    player.play()
                }
            } catch {
                print("error")
            }
        }
    }

    @objc private func voiceOverNotification() {
//        NSLog("\(UIAccessibility.isVoiceOverRunning)")
//        if UIAccessibility.isVoiceOverRunning { return }
        _ = dequeueSpeak()
    }
}

extension AudioManager: AVSpeechSynthesizerDelegate {
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        AudioServicesPlaySystemSound(1102)
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        self.isPlaying = false
        _ = self.dequeueSpeak()
    }
}

extension AudioManager: AVAudioPlayerDelegate {
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.isSoundEffect = false
    }
}
