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


open class STTHelper: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, SFSpeechRecognizerDelegate {
    
    fileprivate let speechRecognizer = SFSpeechRecognizer()!
    fileprivate var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    fileprivate var recognitionTask: SFSpeechRecognitionTask?
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var button: UIButton!
    
    var tts:TTSProtocol?
    var delegate:DialogViewHelper?
    var speaking:Bool = false
    var recognizing:Bool = false
    var paused:Bool = true
    var restarting:Bool = true
    var last_actions: [([String],(String, UInt64)->Void)]?
    var last_failure:(NSError)->Void = {arg in}
    var last_timeout:(Void)->Void = {arg in}
    var last_text: String = ""
    var listeningStart:Double = 0
    var avePower:Double = 0
    var aveCount:Int64 = 0
    var stopstt:()->()
    
    var pwCaptureSession:AVCaptureSession? = nil
    var audioDataQueue:DispatchQueue? = nil
    
    var arecorder:AVAudioRecorder? = nil
    var timeoutTimer:Timer? = nil
    var timeoutDuration:TimeInterval = 20.0
    var ametertimer:Timer? = nil
    var resulttimer:Timer? = nil
    var resulttimerDuration:TimeInterval = 1.0
    var confidenceFilter = 0.2
    var executeFilter = 0.3
    var hesitationPrefix = "D_"
    
    override init() {
        self.stopstt = {}
        self.audioDataQueue = DispatchQueue(label: "hulop.conversation", attributes: [])
        super.init()
        self.initAudioRecorder()

        speechRecognizer.delegate = self
        SFSpeechRecognizer.requestAuthorization { authStatus in
            print(authStatus);
        }
    }
    fileprivate func initAudioRecorder(){
        let doc = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)[0]
        var url = URL(fileURLWithPath: doc)
        url = url.appendingPathComponent("recordTest.caf")
        let recsettings:[String:AnyObject] = [
            AVFormatIDKey: Int(kAudioFormatAppleIMA4) as AnyObject,
            AVSampleRateKey:44100.0 as AnyObject,
            AVNumberOfChannelsKey:2 as AnyObject,
            AVEncoderBitRateKey:12800 as AnyObject,
            AVLinearPCMBitDepthKey:16 as AnyObject,
            AVEncoderAudioQualityKey:AVAudioQuality.max.rawValue as AnyObject
        ]
        
        self.arecorder = try? AVAudioRecorder(url:url,settings:recsettings)
    }
    var frecCaptureSession:AVCaptureSession? = nil
    var frecDataQueue:DispatchQueue? = nil
    func startRecording(_ input: AVCaptureDeviceInput){
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
    
    func createError(_ message:String) -> NSError{
        let domain = "swift.sttHelper"
        let code = -1
        let userInfo = [NSLocalizedDescriptionKey:message]
        return NSError(domain:domain, code: code, userInfo:userInfo)
    }
    
    fileprivate func startPWCaptureSession(){//alternative
        if nil == self.pwCaptureSession{
            self.pwCaptureSession = AVCaptureSession()
            if let captureSession = self.pwCaptureSession{
                let microphoneDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
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
    fileprivate func stopPWCaptureSession(){
        self.pwCaptureSession?.stopRunning()
    }

    open func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        recognitionRequest?.appendAudioSampleBuffer(sampleBuffer)                
        
        let channels = connection.audioChannels
        var peak:Float = 0;
        for chnl in channels!{
            peak = (chnl as AnyObject).averagePowerLevel
        }
        DispatchQueue.main.async{
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
    
    func startAudioMetering(_ delegate: AVAudioRecorderDelegate?){
        self.stopAudioMetering()
        if let delegate = delegate{
            self.arecorder?.delegate = delegate
        }
        self.arecorder?.isMeteringEnabled = true
        self.startAudioRecorder()
        self.ametertimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(STTHelper.onamUpdate),userInfo:nil, repeats:true)
        self.ametertimer?.fire()
    }
    func onamUpdate(){
        self.arecorder?.updateMeters()
        if let ave = self.arecorder?.averagePower(forChannel: 0){
            self.delegate?.setMaxPower(ave + 120)
            //            print(ave)
        }
    }
    func stopAudioMetering(){
        if self.ametertimer != nil{
            self.arecorder?.isMeteringEnabled = false
            self.ametertimer?.invalidate()
            self.ametertimer = nil
        }
        self.stopAudioRecorder()
    }
    
    func startRecognize(_ actions: [([String],(String, UInt64)->Void)], failure: @escaping (NSError)->Void,  timeout: @escaping (Void)->Void){
        self.paused = false
        
        let audioSession:AVAudioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setActive(true)
        } catch {
        }
        
        self.last_timeout = timeout
        self.last_failure = failure
        
        /*
        let strs = ["おしゃれでお酒が飲めるイタリアン","テスト","中華料理","ファッション","はい","いいえ","バッグ","美味しいお店"]
        let i = arc4random_uniform(UInt32(strs.count))
        let str = strs[Int(i)]
        
        if str.characters.count > 0 {
            for action in actions {
                let patterns = action.0
                for pattern in patterns {
                    if self.checkPattern(pattern, str) {
                        NSLog("Matched pattern = \(pattern)")
                        self.endRecognize();
                        self.delegate?.recognize()
                        return (action.1)(str, 1000)
                    }
                }
            }
            return
        }
 */
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest!.shouldReportPartialResults = true
        last_text = ""
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest!, resultHandler: { [weak self] (result, e) in
            guard let weakself = self else {
                return
            }
            let complete:(Void)->Void = {
                if weakself.last_text.characters.count == 0 { return }
                for action in actions {
                    let patterns = action.0
                    for pattern in patterns {
                        if weakself.checkPattern(pattern, weakself.last_text) {
                            NSLog("Matched pattern = \(pattern)")
                            weakself.endRecognize();
                            weakself.delegate?.recognize()
                            return (action.1)(weakself.last_text, 0)
                        }
                    }
                }
            }

            if e != nil {
                weakself.stoptimer()
                guard let error:NSError = e as? NSError else {
                    print(e!)
                    weakself.endRecognize()
                    timeout()
                    return;
                }

                let code = error.code
                if code == 203 { // Empty recognition
                    weakself.endRecognize();
                    weakself.delegate?.recognize()
                    timeout()
                } else if code == 209 || code == 216 || code == 1700 {
                    // noop
                    // 209 : trying to stop while starting
                    // 216 : terminated by manual
                    // 1700: background
                    complete()
                } else if code == 4 {
                    weakself.endRecognize(); // network error
                    let newError = weakself.createError(NSLocalizedString("checkNetworkConnection", comment:""))
                    failure(newError)
                } else {
                    weakself.endRecognize()
                    failure(error) // unknown error
                }
                return;
            }
            
            if result == nil {
                return;
            }
    
            weakself.stoptimer();
            
            var millisecDuration:UInt64 = 0;
            for s in (result?.bestTranscription.segments)! {
                millisecDuration = millisecDuration + UInt64(s.duration*1000);
            }
            weakself.last_text = (result?.bestTranscription.formattedString)!;

            weakself.resulttimer = Timer.scheduledTimer(withTimeInterval: weakself.resulttimerDuration, repeats: false, block: { (timer) in
                weakself.endRecognize()
            })
            
            let str = weakself.last_text
            let isFinal:Bool = (result?.isFinal)!;
            let length:Int = str.characters.count
            NSLog("Result = \(str), Length = \(length), isFinal = \(isFinal)");
            if (str.characters.count > 0) {
                weakself.delegate?.showText(str);
                if isFinal{
                    complete()
                }
            }else{
                if isFinal{
                    weakself.delegate?.showText("?")
                }
            }
        })
        self.stopstt = {
            self.recognitionTask?.cancel()
            if self.resulttimer != nil{
                self.resulttimer?.invalidate()
                self.resulttimer = nil;
            }
            self.stopstt = {}
        }
        
        self.timeoutTimer = Timer.scheduledTimer(withTimeInterval: self.timeoutDuration, repeats: false, block: { (timer) in
            self.endRecognize()
            timeout()
        })
        
        self.restarting = false
        self.recognizing = true
    }
    
    func stoptimer(){
        if self.resulttimer != nil{
            self.resulttimer?.invalidate()
            self.resulttimer = nil
        }
        if self.timeoutTimer != nil {
            self.timeoutTimer?.invalidate()
            self.timeoutTimer = nil
        }
    }
    
    internal func _setTimeout(_ delay:TimeInterval, block:@escaping ()->Void) -> Timer {
        return Timer.scheduledTimer(timeInterval: delay, target: BlockOperation(block: block), selector: #selector(Operation.main), userInfo: nil, repeats: false)
    }
    
    func listen(_ actions: [([String],(String, UInt64)->Void)], selfvoice: String?, speakendactions:[((String)->Void)]?,avrdelegate:AVAudioRecorderDelegate?, failure:@escaping (NSError)->Void, timeout:@escaping (Void)->Void) {
        
        if (speaking) {
            NSLog("TTS is speaking so this listen is eliminated")
            return
        }
        NSLog("Listen \(selfvoice) \(actions)")
        self.last_actions = actions

        self.stoptimer()
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

            let delay = 0.4
            NavSound.sharedInstance().vibrate(nil)
            NavSound.sharedInstance().playVoiceRecoStart()
            
            _ = self._setTimeout(delay, block: {
                self.startPWCaptureSession()//alternative
                self.startRecognize(actions, failure: failure, timeout: timeout)
                
                self.delegate?.showText(NSLocalizedString("SPEAK_NOW", comment:"Speak Now!"))
                self.delegate?.listen()
            })
            
        }
        speaking = true
    }
    
    func now() -> Double {
        return Date().timeIntervalSince1970
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
        self.stoptimer()

        let avs:AVAudioSession = AVAudioSession.sharedInstance()
        do {
            try avs.setCategory(AVAudioSessionCategorySoloAmbient)
            try avs.setActive(true)
        } catch {
        }
    }
    
    func endRecognize() {
        tts?.stop()
        self.speaking = false
        self.recognizing = false
        self.stopAudioMetering()
        self.arecorder?.stop()
        self.stopPWCaptureSession()
        self.stopstt()
        self.stoptimer()

        let avs:AVAudioSession = AVAudioSession.sharedInstance()
        do {
            try avs.setCategory(AVAudioSessionCategorySoloAmbient)
            try avs.setActive(true)
        } catch {
        }
    }
    
    func restartRecognize() {
        self.paused = false;
        self.restarting = true;
        if let actions = self.last_actions {
            let delay = 0.4
            NavSound.sharedInstance().vibrate(nil)
            NavSound.sharedInstance().playVoiceRecoStart()
            
            _ = self._setTimeout(delay, block: {
                self.startPWCaptureSession()
                self.startRecognize(actions, failure:self.last_failure, timeout:self.last_timeout)
            })
        }
    }

    func checkPattern(_ pattern: String?, _ text: String?) -> Bool {
        if text != nil {
            do {
                var regex:NSRegularExpression?;
                try regex = NSRegularExpression(pattern: pattern!, options: NSRegularExpression.Options.caseInsensitive)
                if (regex?.matches(in: text!, options: NSRegularExpression.MatchingOptions.reportProgress, range: NSMakeRange(0, (text?.characters.count)!)).count)! > 0 {
                    return true
                }
            } catch {
                
            }
        }
        
        return false
    }
}
