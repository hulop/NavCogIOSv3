/*******************************************************************************
 * Copyright (c) 2014, 2016  IBM Corporation, Carnegie Mellon University and others
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
import AVFoundation
import Speech


public class STTHelper: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, SFSpeechRecognizerDelegate {
    
    private let speechRecognizer = SFSpeechRecognizer()!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var button: UIButton!
    
    var tts:TTSProtocol?
    var delegate:DialogViewHelper?
    var speaking:Bool = false
    var recognizing:Bool = false
    var paused:Bool = true
    var last_actions: [([String],(String, UInt64)->Void)]?
    var last_failure:(NSError)->Void = {arg in}
    var listeningStart:Double = 0
    var avePower:Double = 0
    var aveCount:Int64 = 0
    var stopstt:()->()
    
    var pwCaptureSession:AVCaptureSession? = nil
    var audioDataQueue:dispatch_queue_t? = nil
    
    var arecorder:AVAudioRecorder? = nil
    var ametertimer:NSTimer? = nil
    var resulttimer:NSTimer? = nil
    var resulttimerDuration:NSTimeInterval = 2.0
    var confidenceFilter = 0.2
    var executeFilter = 0.3
    var hesitationPrefix = "D_"
    
    override init() {
        self.stopstt = {}
        self.audioDataQueue = dispatch_queue_create("hulop.conversation", DISPATCH_QUEUE_SERIAL)
        super.init()
        self.initAudioRecorder()

        speechRecognizer.delegate = self
        SFSpeechRecognizer.requestAuthorization { authStatus in
            print(authStatus);
        }
    }
    private func initAudioRecorder(){
        let doc:AnyObject = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)[0]
        let path = doc.stringByAppendingPathComponent("recordTest.caf")
        let url = NSURL.fileURLWithPath(path as String)
        let recsettings:[String:AnyObject] = [
            AVFormatIDKey: Int(kAudioFormatAppleIMA4),
            AVSampleRateKey:44100.0,
            AVNumberOfChannelsKey:2,
            AVEncoderBitRateKey:12800,
            AVLinearPCMBitDepthKey:16,
            AVEncoderAudioQualityKey:AVAudioQuality.Max.rawValue
        ]
        
        self.arecorder = try? AVAudioRecorder(URL:url,settings:recsettings)
    }
    var frecCaptureSession:AVCaptureSession? = nil
    var frecDataQueue:dispatch_queue_t? = nil
    func startRecording(input: AVCaptureDeviceInput){
        self.stopRecording()
        self.frecCaptureSession = AVCaptureSession()
        if frecCaptureSession!.canAddInput(input){
            frecCaptureSession!.addInput(input)
        }
    }
    func stopRecording(){
        if self.frecCaptureSession != nil{
            self.frecCaptureSession?.stopRunning()
            for output in self.frecCaptureSession!.outputs{
                self.frecCaptureSession?.removeOutput(output as! AVCaptureOutput)
            }
            for input in self.frecCaptureSession!.inputs{
                self.frecCaptureSession?.removeInput(input as! AVCaptureInput)
            }
            self.frecCaptureSession = nil
        }
    }
    
    func createError(message:String) -> NSError{
        let domain = "swift.sttHelper"
        let code = -1
        let userInfo = [NSLocalizedDescriptionKey:message]
        return NSError(domain:domain, code: code, userInfo:userInfo)
    }
    
    private func startPWCaptureSession(){//alternative
        if nil == self.pwCaptureSession{
            self.pwCaptureSession = AVCaptureSession()
            if let captureSession = self.pwCaptureSession{
                let microphoneDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio)
                let microphoneInput = try? AVCaptureDeviceInput(device: microphoneDevice)
                if(captureSession.canAddInput(microphoneInput)){
                    captureSession.addInput(microphoneInput)
                    let adOutput = AVCaptureAudioDataOutput()
                    adOutput.setSampleBufferDelegate(self, queue: self.audioDataQueue)
                    if captureSession.canAddOutput(adOutput){
                        captureSession.addOutput(adOutput)
                    }
                }
            }
        }
        self.pwCaptureSession?.startRunning()
    }
    private func stopPWCaptureSession(){
        self.pwCaptureSession?.stopRunning()
    }

    public func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        recognitionRequest?.appendAudioSampleBuffer(sampleBuffer)                
        
        let channels = connection.audioChannels
        var peak:Float = 0;
        for chnl in channels!{
            peak = (chnl as AnyObject).averagePowerLevel
        }
        dispatch_async(dispatch_get_main_queue()){
            self.delegate?.setMaxPower(peak + 110)
        }
    }
    func startAudioRecorder(){
        self.stopAudioRecorder()
        
        self.arecorder?.record()
    }
    func stopAudioRecorder(){
        self.arecorder?.stop()
    }
    
    func startAudioMetering(delegate: AVAudioRecorderDelegate?){
        self.stopAudioMetering()
        if let delegate = delegate{
            self.arecorder?.delegate = delegate
        }
        self.arecorder?.meteringEnabled = true
        self.startAudioRecorder()
        self.ametertimer = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: #selector(STTHelper.onamUpdate),userInfo:nil, repeats:true)
        self.ametertimer?.fire()
    }
    func onamUpdate(){
        self.arecorder?.updateMeters()
        if let ave = self.arecorder?.averagePowerForChannel(0){
            self.delegate?.setMaxPower(ave + 120)
            //            print(ave)
        }
    }
    func stopAudioMetering(){
        if self.ametertimer != nil{
            self.arecorder?.meteringEnabled = false
            self.ametertimer?.invalidate()
            self.ametertimer = nil
        }
        self.stopAudioRecorder()
    }
    
    func startRecognize(actions: [([String],(String, UInt64)->Void)], failure: (NSError)->Void){
        let audioSession:AVAudioSession = AVAudioSession.sharedInstance()
        try! audioSession.setCategory(AVAudioSessionCategoryRecord)
        try! audioSession.setActive(true)

        self.recognizing = true
        self.paused = false
        self.last_failure = failure
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest!.shouldReportPartialResults = true
        recognitionTask = speechRecognizer.recognitionTaskWithRequest(recognitionRequest!, resultHandler: { result, error in
            if error != nil {
                print(error)
                if let code = error?.code {
                    if code == 203 {
                        self.endRecognize();
                        var delay = 0.0
                        //if UIAccessibilityIsVoiceOverRunning() {
                            NavSound.sharedInstance().vibrate(nil)
                            NavSound.sharedInstance().playVoiceRecoStart()
                            delay = 0.25
                        //}
                        
                        self._setTimeout(delay, block: {
                            self.startPWCaptureSession()
                            self.startRecognize(actions, failure:failure)
                        })
                    } else if code == 216 || code == 1700 {
                        // noop 
                        // 216 : terminated by manual
                        // 1700: background
                        return;
                    } else if code == 4 {
                        self.endRecognize(); // network error
                        
                        let newError = self.createError(NSLocalizedString("checkNetworkConnection", comment:""))
                        failure(newError)
                    } else {
                        self.endRecognize()
                        failure(error!)
                    }
                }
                return;
            }
            
            print(result)
            if result == nil {
                return;5
            }
            
            if self.resulttimer != nil{
                self.resulttimer?.invalidate()
                self.resulttimer = nil;
            }
            
            var millisecDuration:UInt64 = 0;
            for s in (result?.bestTranscription.segments)! {
                millisecDuration = millisecDuration + UInt64(s.duration*1000);
            }
            let str:String = (result?.bestTranscription.formattedString)!;

            self.resulttimer = NSTimer.scheduledTimerWithTimeInterval(self.resulttimerDuration, repeats: false, block: { (timer) in
                for action in actions {
                    let patterns = action.0
                    for pattern in patterns {
                        if self.checkPattern(pattern, str) {
                            NSLog("Matched pattern = \(pattern)")
                            self.endRecognize();
                            self.delegate?.recognize()
                            return (action.1)(str, millisecDuration)
                        }
                    }
                }
            })
            
            let isFinal:Bool = (result?.final)!;
            let length:Int = str.characters.count
            NSLog("Result = \(str), Length = \(length), isFinal = \(isFinal)");
            if (str.characters.count > 0) {
                self.delegate?.showText(str);
                if isFinal{
                    for action in actions {
                        let patterns = action.0
                        for pattern in patterns {
                            if self.checkPattern(pattern, str) {
                                NSLog("Matched pattern = \(pattern)")
                                self.endRecognize();
                                self.delegate?.recognize()
                                return (action.1)(str, millisecDuration)
                            }
                        }
                    }
                }
            }else{
                if isFinal{
                    self.delegate?.showText("?")
                }
            }
        })
        self.stopstt = {
            self.recognitionTask?.cancel()
            self.stopstt = {}
        }
    }
    
    
    internal func _setTimeout(delay:NSTimeInterval, block:()->Void) -> NSTimer {
        return NSTimer.scheduledTimerWithTimeInterval(delay, target: NSBlockOperation(block: block), selector: #selector(NSOperation.main), userInfo: nil, repeats: false)
    }
    
    func listen(actions: [([String],(String, UInt64)->Void)], selfvoice: String?, speakendactions:[((String)->Void)]?,avrdelegate:AVAudioRecorderDelegate?, failure:(NSError)->Void) {
        
        if (speaking) {
            NSLog("TTS is speaking so this listen is eliminated")
            return
        }
        NSLog("Listen \(selfvoice) \(actions)")
        self.last_actions = actions

        delegate?.speak()
        delegate?.showText(" ")
        tts?.speak(selfvoice) {
            if (!self.speaking) {
                return
            }
            self.speaking = false
            if speakendactions != nil {
                for act in speakendactions!{
                    (act)(selfvoice!)
                }
            }
            self.listeningStart = self.now()

            var delay = 0.0
            //if UIAccessibilityIsVoiceOverRunning() {
                NavSound.sharedInstance().vibrate(nil)
                NavSound.sharedInstance().playVoiceRecoStart()
                delay = 0.25
            //}
            
            self._setTimeout(delay, block: {
                self.startPWCaptureSession()//alternative
                self.startRecognize(actions, failure: failure)
                
                self.delegate?.showText(NSLocalizedString("SPEAK_NOW", comment:"Speak Now!"))
                self.delegate?.listen()
            })
            
        }
        speaking = true
    }
    
    func now() -> Double {
        return NSDate().timeIntervalSince1970
    }
    
    func prepare() {
    }
    
    func disconnect() {
        self.tts?.stop()
        self.speaking = false
        self.recognizing = false
        self.stopAudioMetering()
        self.arecorder?.stop()
        self.stopPWCaptureSession()
        self.stopstt()
        
        let avs:AVAudioSession = AVAudioSession.sharedInstance()
        try! avs.setCategory(AVAudioSessionCategorySoloAmbient)
        try! avs.setActive(true)
    }
    
    func endRecognize() {
        tts?.stop()
        self.speaking = false
        self.recognizing = false
        self.stopAudioMetering()
        self.arecorder?.stop()
        self.stopPWCaptureSession()
        self.stopstt()
        
        let avs:AVAudioSession = AVAudioSession.sharedInstance()
        try! avs.setCategory(AVAudioSessionCategorySoloAmbient)
        try! avs.setActive(true)
    }
    
    func restartRecognize() {
        if let actions = self.last_actions {
            if let failure:(NSError)->Void = self.last_failure {
                var delay = 0.0
                //if UIAccessibilityIsVoiceOverRunning() {
                    NavSound.sharedInstance().vibrate(nil)
                    //NavSound.sharedInstance().playVoiceRecoStart()
                    delay = 0.0
                //}
                
                self._setTimeout(delay, block: {
                    self.startPWCaptureSession()
                    self.startRecognize(actions, failure:failure)
                })
            }
        }
    }

    func checkPattern(pattern: String?, _ text: String?) -> Bool {
        if text != nil {
            do {
                var regex:NSRegularExpression?;
                try regex = NSRegularExpression(pattern: pattern!, options: NSRegularExpressionOptions.CaseInsensitive)
                if (regex?.matchesInString(text!, options: NSMatchingOptions.ReportProgress, range: NSMakeRange(0, (text?.characters.count)!)).count)! > 0 {
                    return true
                }
            } catch {
                
            }
        }
        
        return false
    }
}
