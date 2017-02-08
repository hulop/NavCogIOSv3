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
import Alamofire
import Freddy
import AVFoundation

class servicecred{
    internal let url:String
    internal let user:String
    internal let pass:String
    init(_url:String, _user:String, _pass:String){
        self.url = _url
        self.user = _user
        self.pass = _pass
    }
}
protocol ControlViewDelegate: class {
    func elementFocusedByVoiceOver()
    func actionPerformedByVoiceOver()
}

class DialogViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, LocalContextDelegate, ControlViewDelegate, DialogViewDelegate{
    deinit {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self)
        DialogManager.sharedManager().available = true
    }

    var imageView: UIImageView? = nil
    var tableView: UITableView? = nil
    var controlView: ControlView? = nil
    var conversation_id:String? = nil
    var client_id:Int? = nil
    var root: UIViewController? = nil
    let tintColor: UIColor = UIColor(red: 0, green: 0.478431, blue: 1, alpha: 1)
    
    private var _tts:TTSProtocol? = nil
    private var _stt:STTHelper? = nil
    
    let conv_devicetype:String = UIDevice.currentDevice().systemName + "_" + UIDevice.currentDevice().systemVersion
    let conv_deviceid:String = (UIDevice.currentDevice().identifierForVendor?.UUIDString)!
    var conv_context:NSDictionary? = nil
    var conv_server:String? = nil
    var conv_api_key:String? = nil
    var conv_client_id:String? = nil
    let conv_navigation_url = "navcog3://start_navigation/"
    let conv_context_local:LocalContext = LocalContext()
    var conv_started = false
    
    let defbackgroundColor:UIColor = UIColor(red: CGFloat(221/255.0), green: CGFloat(222/255.0), blue: CGFloat(224/255.0), alpha:1.0)
    let blue:UIColor = UIColor(red: CGFloat(50/255.0), green: CGFloat(92/255.0), blue: CGFloat(128/255.0), alpha:1.0)
    let white:UIColor = UIColor(red: CGFloat(244/255.0), green: CGFloat(244/255.0), blue: CGFloat(236/255.0), alpha:1.0)
    let black:UIColor = UIColor(red: CGFloat(65/255.0), green: CGFloat(70/255.0), blue: CGFloat(76/255.0), alpha:1.0)
    
    var tableData:[Dictionary<String,AnyObject>]!
    var heightLeftCell: CustomLeftTableViewCell = CustomLeftTableViewCell()
    var heightRightCell: CustomRightTableViewCell = CustomRightTableViewCell()
    
    private var dialogViewHelper: DialogViewHelper = DialogViewHelper()
    var cancellable = false
    
    
    let ttslock:NSLock = NSLock()
    private func getTts() -> TTSProtocol{
        self.ttslock.lock()
        defer{self.ttslock.unlock()}
        if let tts = self._tts{
            return tts
        }else{
            self._tts = DefaultTTS()
            return self._tts!
        }
    }
    let sttlock:NSLock = NSLock()
    private func getStt() -> STTHelper{
        self.sttlock.lock()
        defer{self.sttlock.unlock()}
        if let stt = self._stt{
            return stt
        }else{
            self._stt = STTHelper()
            self._stt!.tts = self.getTts()
            self._stt!.prepare()
            return self._stt!
        }
    }
    internal func startConversation(){
        self.initConversationConfig()//override with local setting
        self.conv_context_local.verifyPrivacy()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        self.conv_context_local.delegate = self
        self.getStt()
        self.conv_context = nil
        self.tableData = []

        let nc = NSNotificationCenter.defaultCenter()
        nc.addObserver(self, selector: #selector(resetConversation), name: "ResetConversation", object: nil)
        nc.addObserver(self, selector: #selector(restartConversation), name: "RestartConversation", object: nil)
        nc.addObserver(self, selector: #selector(requestDialogEnd), name: REQUEST_DIALOG_END, object: nil)
        nc.addObserver(self, selector: #selector(requestDialogAction), name: REQUEST_DIALOG_ACTION, object: nil)
    }
    
    internal func updateView() {
    }

    override func viewWillAppear(animated: Bool) {
        self.updateView()
    }
    
    override func viewDidAppear(animated: Bool) {
        NSNotificationCenter.defaultCenter().postNotificationName("RestartConversation", object: self)
    }
    
    override func viewWillDisappear(animated: Bool) {
        NSNotificationCenter.defaultCenter().postNotificationName("ResetConversation", object: self)
        self.updateView()
    }
    
    internal func showNoSpeechRecoAlert() {
        let title = NSLocalizedString("NoSpeechRecoAccessAlertTitle", comment:"");
        let message = NSLocalizedString("NoSpeechRecoAccessAlertMessage", comment:"");
        let setting = NSLocalizedString("SETTING", comment:"");
        let cancel = NSLocalizedString("CANCEL", comment:"");
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: setting, style: UIAlertActionStyle.Default, handler: { (action) in
            let url = NSURL(string:"App-Prefs:root=Privacy")
            UIApplication.sharedApplication().openURL(url!, options:[:], completionHandler: { (success) in
            })
        }))
        alert.addAction(UIAlertAction(title: cancel, style: UIAlertActionStyle.Default, handler: { (action) in
        }))
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: {
            })
        })
        cancellable = true
        self.updateView()
        
        self.tableData.append(["name": NSLocalizedString("Error", comment:""), "type": 1,  "image": "conversation.png", "message": message])
        self.refreshTableView()
    }
    
    internal func showNoAudioAccessAlert(){
        let title = NSLocalizedString("NoAudioAccessAlertTitle", comment:"");
        let message = NSLocalizedString("NoAudioAccessAlertMessage", comment:"");
        let setting = NSLocalizedString("SETTING", comment:"");
        let cancel = NSLocalizedString("CANCEL", comment:"");

        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: setting, style: UIAlertActionStyle.Default, handler: { (action) in
            let url = NSURL(string:"App-Prefs:root=Privacy")
            UIApplication.sharedApplication().openURL(url!, options:[:], completionHandler: { (success) in
            })
        }))
        alert.addAction(UIAlertAction(title: cancel, style: UIAlertActionStyle.Default, handler: { (action) in
        }))
        dispatch_async(dispatch_get_main_queue(), {
            self.presentViewController(alert, animated: true, completion: { 
            })
        })
        cancellable = true
        self.updateView()
        
        self.tableData.append(["name": NSLocalizedString("Error", comment:""), "type": 1,  "image": "conversation.png", "message": message])
        self.refreshTableView()
    }
    
    internal func requestDialogEnd() {
        if cancellable {
            self.navigationController?.popToRootViewControllerAnimated(true)
        } else {
            NavSound.sharedInstance().playFail()
        }
    }
    internal func requestDialogAction() {
        self.tapped()
    }
    
    internal func resetConversation(){
        DialogManager.sharedManager().available = false
        self.getStt().disconnect()
        _stt?.delegate = nil
        _stt = nil
        _tts = nil
        self.conv_context_local.delegate = nil
        self.conv_context = nil
        self.tableData = []
        if let tableview = self.tableView{
            tableview.removeFromSuperview()
            self.tableView!.delegate = self
            self.tableView!.dataSource = self
            self.tableView = nil
        }
        self.dialogViewHelper.reset()
        self.dialogViewHelper.removeFromSuperview()
        self.dialogViewHelper.delegate = nil
    }
    internal func restartConversation(){
        dispatch_async(dispatch_get_main_queue()) {
            self.conv_context_local.delegate = self
            self.getStt().prepare()
            self.initDialogView()
            self.conv_started = false
            self.startConversation()
        }
        
    }
    internal func onContextChange(context:LocalContext){
        if !self.conv_started{
            self.conv_started = true
            self.sendmessage("")
        }
    }
    private func initConversationConfig(){
        let defs:NSDictionary = ServerConfig.sharedConfig().selectedServerConfig;

        let server = defs["conv_server"]
        if let _server = server as? String {
            if !_server.isEmpty {
                self.conv_server = _server
            }
        }
        let key = defs["conv_api_key"]
        if let _key = key as? String {
            if !_key.isEmpty {
                self.conv_api_key = _key
            }
        }
        let str = NavDataStore.sharedDataStore().userID!
        if  !str.isEmpty {
            self.conv_client_id = str
        }
    }

    class NoVoiceTableView: UITableView {
        override var accessibilityElementsHidden: Bool {
            set {}
            get { return true }
        }
    }
    
    class ControlView: UIView {
        weak var delegate:ControlViewDelegate?
        override var isAccessibilityElement: Bool {
            set {}
            get { return true }
        }
        override var accessibilityLabel: String? {
            set {}
            get {
                return NSLocalizedString("DialogStart", comment: "")
            }
        }
        override var accessibilityHint: String? {
            set {}
            get {
                return NSLocalizedString("DialogStartHint", comment: "")
            }
        }
        override var accessibilityTraits: UIAccessibilityTraits {
            set {}
            get {
                return UIAccessibilityTraitButton
            }
        }
        override func accessibilityElementDidBecomeFocused() {
            if delegate != nil {
                delegate!.elementFocusedByVoiceOver()
            }
        }
        override func accessibilityActivate() -> Bool {
            if delegate != nil {
                delegate!.actionPerformedByVoiceOver()
            }
            return true
        }
    }
    private func initDialogView(){
        self.view.backgroundColor = defbackgroundColor
       if(nil == self.tableView){
            // chat messages
            self.tableView = NoVoiceTableView()
            self.tableView!.registerClass(CustomLeftTableViewCell.self, forCellReuseIdentifier: "CustomLeftTableViewCell")
            self.tableView!.registerClass(CustomRightTableViewCell.self, forCellReuseIdentifier: "CustomRightTableViewCell")
            self.tableView!.registerClass(CustomLeftTableViewCellSpeaking.self, forCellReuseIdentifier: "CustomLeftTableViewCellSpeaking")
            self.tableView!.delegate = self
            self.tableView!.dataSource = self
            self.tableView!.separatorColor = UIColor.clearColor()
            self.tableView?.backgroundColor = defbackgroundColor
            //        self.tableView!.layer.zPosition = -1
            
            // mic button and dictated text label
            self.controlView = ControlView()
            self.controlView!.delegate = self
            self.controlView!.frame = self.view!.frame
            // show mic button on controlView
            let pos = CGPoint(x: self.view.bounds.width/2, y: self.view.bounds.height - 120)
            dialogViewHelper.setup(self.controlView!, position:pos, tapEnabled: true)
            dialogViewHelper.delegate = self
            
            // add controlView first
            self.view.addSubview(controlView!)
            self.view.addSubview(tableView!)
        }
        
        self.resizeTableView()
    }
    func elementFocusedByVoiceOver() {
        let stt = self.getStt()

        stt.tts?.stop(false)
        stt.disconnect()
        if !stt.paused {
            NavSound.sharedInstance().vibrate(nil)
            NavSound.sharedInstance().playVoiceRecoEnd()
        }
        stt.paused = true
        stt.delegate?.showText(NSLocalizedString("PAUSING", comment:"Pausing"));
        stt.delegate?.inactive()
    }
    func actionPerformedByVoiceOver() {
        let stt = self.getStt()
        if(stt.paused){
            print("restart stt")
            stt.restartRecognize()
            stt.delegate?.showText(NSLocalizedString("SPEAK_NOW", comment:"Speak Now!"));
            stt.delegate?.listen()
            UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.navigationItem.leftBarButtonItem)
        }
    }
    
    private func resizeTableView(){
        if(nil == self.tableView){
            return
        }

        let statusBarHeight: CGFloat = UIApplication.sharedApplication().statusBarFrame.height + 40
        let txheight = self.dialogViewHelper.helperView.bounds.height + self.dialogViewHelper.label.bounds.height
        
        let displayWidth: CGFloat = self.view.frame.width
        let displayHeight: CGFloat = self.view.frame.height
        self.tableView!.frame = CGRect(x:0, y:statusBarHeight, width:displayWidth, height:displayHeight - statusBarHeight - txheight)
    }
    private func initImageView(){
        let image1:UIImage? = UIImage(named:"Dashboard.PNG")
        
        self.imageView = UIImageView(frame:self.view.bounds)
        self.imageView!.image = image1
        
        self.view.addSubview(self.imageView!)
    }
    private func removeImageView(){
        self.imageView?.removeFromSuperview()
    }
    override func viewDidLayoutSubviews() {
        self.resizeTableView()

    }
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat
    {
        if self.tableData.count <= indexPath.row {
            return 0
        }
        
        let type:Int = self.tableData[indexPath.row]["type"] as! Int
        if 1 == type {
            return heightLeftCell.setData(tableView.frame.size.width - 20, data: self.tableData[indexPath.row])
        }
        else if 2 == type{
            return heightRightCell.setData(tableView.frame.size.width - 20, data: self.tableData[indexPath.row])
        }else{//3
            return self.heightLeftCell.setData(tableView.frame.size.width - 20, data: self.tableData[indexPath.row])
        }
    }
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        var type:Int = 1
        if indexPath.row < self.tableData.count {
            type = self.tableData[indexPath.row]["type"] as! Int
        }
        if 1 == type
        {
            let cell = tableView.dequeueReusableCellWithIdentifier("CustomLeftTableViewCell", forIndexPath: indexPath) as! CustomLeftTableViewCell
            cell.backgroundColor = defbackgroundColor
            cell.fillColor = white
            cell.fontColor = black
            cell.strokeColor = blue
            cell.setData(tableView.frame.size.width - 20, data: self.tableData[indexPath.row])
            return cell
        }
        else if 2 == type
        {
            let cell = tableView.dequeueReusableCellWithIdentifier("CustomRightTableViewCell", forIndexPath: indexPath) as! CustomRightTableViewCell
            cell.backgroundColor = defbackgroundColor
            cell.fillColor = blue
            cell.fontColor = white
            cell.strokeColor = blue
            cell.setData(tableView.frame.size.width - 20, data: self.tableData[indexPath.row])
            return cell
        }else{
            let cell = tableView.dequeueReusableCellWithIdentifier("CustomLeftTableViewCellSpeaking", forIndexPath: indexPath) as! CustomLeftTableViewCellSpeaking
            cell.backgroundColor = defbackgroundColor
            cell.fillColor = white
            cell.fontColor = black
            cell.strokeColor = blue
            cell.setData(tableView.frame.size.width - 20, data: self.tableData[indexPath.row])
            return cell
        }
    }
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData.count
    }
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    internal func refreshTableView(dontscroll:Bool? = false){
        if(nil == self.tableView){
            return
        }
        dispatch_async(dispatch_get_main_queue(), { [weak self] in
            if let weakself = self {
                weakself.tableView?.reloadData()
                if !dontscroll!{
                    dispatch_async(dispatch_get_main_queue(),{
                        if(nil == weakself.tableView){
                            return
                        }
                        let nos = weakself.tableView!.numberOfSections
                        let nor = weakself.tableView!.numberOfRowsInSection(nos-1)
                        if nor > 0{
                            let lastPath:NSIndexPath = NSIndexPath(forRow:nor-1, inSection:nos-1)
                            weakself.tableView!.scrollToRowAtIndexPath( lastPath , atScrollPosition: .Bottom, animated: true)
                        }
                    })
                }
            }
        })
    }
    
    func tapped() {
        let stt = self.getStt()
        if (stt.recognizing) {
            print("pause stt")
            stt.endRecognize()
            stt.paused = true
            stt.delegate?.showText(NSLocalizedString("PAUSING", comment:"Pausing"));
            stt.delegate?.inactive()
            NavSound.sharedInstance().playVoiceRecoPause()
        } else if(stt.speaking) {
            print("stop tts")
            stt.tts?.stop() // do not use "true" flag beacus it causes no-speaking problem.
            stt.delegate?.showText(NSLocalizedString("PAUSING", comment:"Pausing"));
            stt.delegate?.inactive()
        } else if(stt.paused){
            print("restart stt")
            stt.restartRecognize()
            stt.delegate?.showText(NSLocalizedString("SPEAK_NOW", comment:"Speak Now!"));
            stt.delegate?.listen()
        } else if(stt.restarting) {
            print("stt is restarting")
            // noop
        } else {
            stt.tts?.stop(false)
            stt.delegate?.inactive()
        }
    }
    
    internal func matches(txt: String, pattern:String)->[[String]]{
        let nsstr = txt as NSString
        var ret:[[String]] = []
        if let regex = try? NSRegularExpression(pattern: pattern, options:NSRegularExpressionOptions()){
            let result = regex.matchesInString(nsstr as String, options: NSMatchingOptions(), range: NSMakeRange(0, nsstr.length)) 
            if 0 < result.count{
                for i in 0 ..< result.count {
                    var temp: [String] = []
                    for j in 0 ..< result[i].numberOfRanges{
                        temp.append(nsstr.substringWithRange(result[i].rangeAtIndex(j)))
                    }
                    ret.append(temp)
                }
            }
        }
        return ret
    }
    
    internal func _setTimeout(delay:NSTimeInterval, block:()->Void) -> NSTimer {
        return NSTimer.scheduledTimerWithTimeInterval(delay, target: NSBlockOperation(block: block), selector: #selector(NSOperation.main), userInfo: nil, repeats: false)
    }

    var inflight:NSTimer? = nil
    var agent_name = ""
    var lastresponse:MessageResponse? = nil
    internal func newresponse(orgres: MessageResponse?){
        conv_context_local.welcome_shown()
        dispatch_async(dispatch_get_main_queue(), { [weak self] in
            if let weakself = self {
                weakself.cancellable = true
                weakself.updateView()
            }
        })

        self.removeImageView()
        var resobj:MessageResponse? = orgres
        if resobj == nil{
            resobj = self.lastresponse
        }else{
            self.lastresponse = orgres
        }
        let restxt = resobj!.output.text.joinWithSeparator("\n")
        self.conv_context = resobj!.context
        
        if let system = self.conv_context!["system"] {
            if let dialog_request_counter = system["dialog_request_counter"] as? Int{
                if dialog_request_counter > 1 {
                    self.timeoutCount = 0
                }
            }
        }

        if let name:String = resobj!.context["agent_name"] as? String {
            agent_name = name
        }
        
        self.removeWaiting()
        self.tableData.append(["name": agent_name, "type": 1,  "image": "conversation.png", "message": restxt])
        self.refreshTableView()
        var postEndDialog:((Void)->Void)? = nil
        if let fin:Bool = resobj!.context["finish"] as? Bool{ 
            if fin {
                postEndDialog = {
                    self.cancellable = true
                    self.updateView()

                    if self.root != nil {
                        self.navigationController?.popToViewController(self.root!, animated: true)
                    } else {
                        self.navigationController?.popToRootViewControllerAnimated(true)
                    }
                    UIApplication.sharedApplication().openURL(NSURL(string: self.conv_navigation_url + "")!, options: [:], completionHandler: nil)
                    
                }
            }
        }
        if let navi:Bool = resobj!.context["navi"] as? Bool{
            if navi{
                if let dest_info = resobj!.context["dest_info"] {
                    if let nodes:String = dest_info["nodes"] as? String {
                        postEndDialog = { [weak self] in
                            if let weakself = self {
                                weakself.cancellable = true
                                weakself.updateView()
                                
                                if weakself.root != nil {
                                    weakself.navigationController?.popToViewController(weakself.root!, animated: true)
                                } else {
                                    weakself.navigationController?.popToRootViewControllerAnimated(true)
                                }
                                UIApplication.sharedApplication().openURL(NSURL(string: weakself.conv_navigation_url + "?toID=" + nodes.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!)!, options: [:], completionHandler: nil)
                            }
                        }
                    }
                }
            }
        }
        var speech = restxt
        if let pron:String = resobj!.context["output_pron"] as? String {
            speech = pron
        }

        dispatch_async(dispatch_get_main_queue(), { [weak self] in
            if let weakself = self {
                if let callback = postEndDialog {
                    weakself.endDialog(speech)
                    weakself._tts?.speak(speech) {
                        callback()
                    }
                }else{
                    weakself.startDialog(speech)
                }
            }
        })
    }
    internal func newmessage(msg:String){
        self.tableData.append(["name":"myself", "type": 2,
            "message":msg ])
        self.refreshTableView()
    }
    
    func removeWaiting() {
        if let timer = self.sendTimeout {
            timer.invalidate()
            self.sendTimeout = nil;
        }
        if let last = self.tableData.last {
            if let lastwaiting = last["waiting"] {
                if lastwaiting as! Bool == true {
                    self.tableData.removeLast()
                }
            }
        }
    }
    
    func showWaiting() {
        sendTimeoutCount = 0
        let table = ["●○○○○","○●○○○","○○●○○","○○○●○","○○○○●","○○○●○","○○●○○","○●○○○","●○○○○"]
        sendTimeout = NSTimer.scheduledTimerWithTimeInterval(0.3, repeats: true, block: { (timer) in
            dispatch_async(dispatch_get_main_queue()) {
                let str = table[self.sendTimeoutCount%table.count]
                self.sendTimeoutCount = self.sendTimeoutCount + 1
                if (self.sendTimeoutCount > 1) {
                    self.tableData.popLast()
                }
                self.tableData.append(["name": self.agent_name, "type": 1,  "waiting":true, "image": "conversation.png", "message": str])
                self.refreshTableView()
            }
        })
    }
    
    var sendTimeout:NSTimer? = nil
    var sendTimeoutCount = 0
    
    internal func sendmessage(msg: String, notimeout: Bool = false){
        if !msg.isEmpty{
            newmessage(msg)

            NavSound.sharedInstance().vibrate(nil)
            NavSound.sharedInstance().playVoiceRecoEnd()
        }

        let conversation = ConversationEx()
        if let context = self.conv_context {
            let ctxdic:NSMutableDictionary = NSMutableDictionary(dictionary: context)
            ctxdic.addEntriesFromDictionary(self.conv_context_local.getContext() as [NSObject : AnyObject])

            conversation.message(msg, server: self.conv_server!, api_key: self.conv_api_key!, client_id: self.conv_client_id, context: ctxdic, failure: { [weak self] (error:NSError) in
                if let weakself = self {
                    weakself.removeWaiting()
                    weakself.failureCustom(error)
                }
            }) { [weak self] response in
                if let weakself = self {
                    let conversationID = response.context["conversation_id"] as! String
                    if conversationID != weakself.conversation_id{
                        weakself.conversation_id = conversationID
                        NSLog("conversationid changed: " + weakself.conversation_id!)
                    }
                    weakself.removeWaiting()
                    weakself.newresponse(response)
                }
            }
        }else{
            conversation.message(msg, server: self.conv_server!, api_key: self.conv_api_key!, client_id: self.conv_client_id, context: self.conv_context_local.getContext(), failure: self.failureCustom) {[weak self] response in
                if let weakself = self {
                    weakself.removeWaiting()
                    weakself.newresponse(response)
                }
            }
        }
        if notimeout == false {
            dispatch_async(dispatch_get_main_queue()) {
                self.showWaiting()
            }
        }
    }
    internal func endspeak(rsp:String?){
        if self.inflight != nil{
            self.inflight?.invalidate()
            self.inflight = nil
        }
    }
    func suspendDialog() {
        let stt = self.getStt()
        stt.endRecognize()
        stt.disconnect()
    }
    func dummy(msg:String){
        //nop
    }

    func headupDialog(speech: String?) {
        let stt:STTHelper = self.getStt()
        stt.endRecognize()
        stt.prepare()
        if speech != nil {
            stt.listen([([".*"], {[weak self] (str, dur) in
                if let weakself = self {
                    weakself.dummy(str)
                }
            })], selfvoice: speech!,
                 speakendactions:[({[weak self] str in
                if let weakself = self {
                    weakself.endspeak(nil)
                }
            })],
                 avrdelegate: nil,
                 failure:{[weak self] (e)in
                if let weakself = self {
                    weakself.failureCustom(e)
            }},
                 timeout:{[weak self] ()in
                if let weakself = self {
                    weakself.timeoutCustom()
            }})
        }else{
            if self._lastspeech != nil{
                self.newresponse(nil)
            }
        }
    }
    var _lastspeech:String? = nil
    func startDialog(response:String) {
        let stt:STTHelper = self.getStt()
        stt.endRecognize()
        stt.delegate = self.dialogViewHelper
        self._lastspeech = response

        stt.listen([([".*"], {[weak self] (str, dur) in
            if let weakself = self {
                weakself.sendmessage(str)
            }
        })], selfvoice: response,speakendactions:[({[weak self] str in
            if let weakself = self {
                if let lastdata = weakself.tableData.last{
                    if 3 == lastdata["type"] as! Int{
                        if weakself.tableView != nil{
                            let nos = weakself.tableView!.numberOfSections
                            let nor = weakself.tableView!.numberOfRowsInSection(nos-1)
                            if nor > 0{
                                let lastPath:NSIndexPath = NSIndexPath(forRow:nor-1, inSection:nos-1)
                                if let tablecell:CustomLeftTableViewCellSpeaking = weakself.tableView!.cellForRowAtIndexPath(lastPath) as? CustomLeftTableViewCellSpeaking{
                                    tablecell.showAllText()
                                }
                            }
                        }
                        let nm = lastdata["name"]
                        let img = lastdata["image"]
                        let msg = lastdata["message"]
                        weakself.tableData.popLast()
                        weakself.tableData.append(["name": nm!, "type": 1, "image": img!, "message": msg!])
                    }
                }
                weakself.endspeak(str)
            }
        })], avrdelegate: nil, failure:{[weak self] (e) in
            if let weakself = self {
                weakself.failureCustom(e)
            }
        }, timeout:{[weak self] (e)in
            if let weakself = self {
                weakself.timeoutCustom(e)
            }
        })
        
    }
    
    func endDialog(response:String){
        let stt:STTHelper = self.getStt()
        stt.endRecognize()
        stt.delegate = self.dialogViewHelper
        self._lastspeech = response
    }
    
    func failDialog() {
        let stt:STTHelper = self.getStt()
        stt.endRecognize()
        stt.paused = true
        stt.delegate?.showText(NSLocalizedString("PAUSING", comment:"Pausing"));
        stt.delegate?.inactive()
        stt.delegate = self.dialogViewHelper
    }
    
    func failureCustom(error: NSError){
        NSLog("%@",error)
        let str = error.localizedDescription
        self.removeWaiting()
        self.tableData.append(["name": NSLocalizedString("Error", comment:""), "type": 1,  "image": "conversation.png", "message": str])
        self.refreshTableView()
        dispatch_async(dispatch_get_main_queue(), { [weak self] in
            if let weakself = self {
                weakself.failDialog()
                weakself._tts?.speak(str) {
                }
            }
            })
        dispatch_async(dispatch_get_main_queue(), { [weak self] in
            if let weakself = self {
                weakself.cancellable = true
                weakself.updateView()
            }
        })
    }
    
    var timeoutCount = 0
    
    func timeoutCustom(){
        if timeoutCount >= 1 {
            let str = NSLocalizedString("WAIT_ACTION", comment:"")
            self.tableData.append(["name": self.agent_name, "type": 1,  "image": "conversation.png", "message": str])
            self.refreshTableView()
            self.failDialog()
            self._tts?.speak(str) {
            }
            return
        }
        
        self.sendmessage("", notimeout: true)
        timeoutCount = timeoutCount + 1
    }
    
    func justSpeech(response: String){
        let stt:STTHelper = self.getStt()
        stt.endRecognize()
        stt.delegate = self.dialogViewHelper
        
        stt.listen([([".*"], {[weak self] str in
            if let weakself = self {
                weakself.sendmessage("")
            }
        })], selfvoice: response,speakendactions:[({[weak self] str in
            if let weakself = self {
                weakself.endspeak(str)
            }
        })], avrdelegate:nil, failure:{[weak self] (error) in
            if let weakself = self {
                weakself.failureCustom(error)
            }
        }, timeout:{[weak self] in
            if let weakself = self {
                weakself.timeoutCustom()
            }
        })
    }
}

