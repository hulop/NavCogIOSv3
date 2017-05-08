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

import UIKit
import Foundation
import Speech

protocol LocalContextDelegate{
    func onContextChange(_ context:LocalContext)
    func showNoAudioAccessAlert()
    func showNoSpeechRecoAlert()
}

open class LocalContext: NSObject{
    fileprivate var context:[String:Any] = [:]
    fileprivate var localvariables:[String:Any] = [:]
    fileprivate static var no_welcome = false

    internal var delegate:LocalContextDelegate?

    override init(){
    }
    
    open func verifyPrivacy() {
        self.verifyAudioAccess();
    }
    
    fileprivate func verifyAudioAccess() {
        AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeAudio, completionHandler: {(granted: Bool) in
            if granted {
                self.verifySpeechRecoAccess()
            } else {
                self.showNoAudioAccessAlert()
            }
        })

    }
    open func verifySpeechRecoAccess() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            if authStatus == .authorized {
                self.notify_delegate_as_needed()
            } else {
                self.showNoSpeechRecoAlert()
            }
        }
    }

    open func welcome_shown() {
        LocalContext.no_welcome = true
    }
    
    open func getContext() -> [String: Any]{
        self.context["local"] = self.localvariables
        if LocalContext.no_welcome {
            self.context["no_welcome"] = true
        }
        DialogManager.sharedManager().setLocationContext(&self.context)
        return self.context
    }
    
    fileprivate func notify_delegate_as_needed(){
        if let del = self.delegate{
            del.onContextChange(self);
        }
    }
    
    fileprivate func showNoAudioAccessAlert(){
        if let del = self.delegate {
            del.showNoAudioAccessAlert()
        }
    }
    fileprivate func showNoSpeechRecoAlert(){
        if let del = self.delegate {
            del.showNoSpeechRecoAlert()
        }
    }
}
