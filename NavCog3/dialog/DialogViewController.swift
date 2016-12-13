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
    }

    var imageView: UIImageView? = nil
    var tableView: UITableView? = nil
    var controlView: ControlView? = nil
    var conversation_id:String? = nil
    var client_id:Int? = nil
    var root: UIViewController? = nil
    
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
        self.onProfileDidChange(NSDictionary())
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initConfiguration()
        self.validateSecurity()
        self.conv_context_local.delegate = self
        self.conv_context_local.start_update_location(1)
        self.getStt()
        self.conv_context = nil
        self.tableData = []

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(resetConversation), name: "ResetConversation", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(restartConversation), name: "RestartConversation", object: nil)
    }

    override func viewWillAppear(animated: Bool) {
        self.navigationController?.navigationBarHidden = false
    }
    override func viewDidAppear(animated: Bool) {
        NSNotificationCenter.defaultCenter().postNotificationName("RestartConversation", object: self)
    }
    override func viewDidDisappear(animated: Bool) {
        NSNotificationCenter.defaultCenter().postNotificationName("ResetConversation", object: self)
    }
    private func validateSecurity(){
        AVCaptureDevice.requestAccessForMediaType(AVMediaTypeAudio, completionHandler: {(granted: Bool) in
        })
        self.conv_context_local.verify_security()
    }
    internal func resetConversation(){
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
        self.getStt().prepare()
        self.initDialogView()
        self.conv_started = false
        self.startConversation()
    }
    internal func onContextChange(context:LocalContext){
        if let prof = context.get_profile() where !context.is_updating() && !self.conv_started{
            self.conv_started = true
            self.sendmessage("")
        }
    }
    internal func onProfileDidChange(profile:NSDictionary){
        self.initConversationConfig()//override with local setting
        self.conv_context_local.set_profile(profile)
    }
    private func initConversationConfig(){
        let defs:NSDictionary = NavDataStore.sharedDataStore().serverConfig()

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
    private func initConfiguration(){
        //self.initAudio()
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
        //stt.endRecognize()
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
        //private let IconSize:CGFloat = 90
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
//        self.refreshTableView()
    }
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat
    {
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
        let type:Int = self.tableData[indexPath.row]["type"] as! Int
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
        dispatch_async(dispatch_get_main_queue(), { [unowned self] in
            self.tableView?.reloadData()
            if !dontscroll!{
                dispatch_async(dispatch_get_main_queue(),{
                    if(nil == self.tableView){
                        return
                    }
                    let nos = self.tableView!.numberOfSections
                    let nor = self.tableView!.numberOfRowsInSection(nos-1)
                    if nor > 0{
                        let lastPath:NSIndexPath = NSIndexPath(forRow:nor-1, inSection:nos-1)
                        self.tableView!.scrollToRowAtIndexPath( lastPath , atScrollPosition: .Bottom, animated: true)
                    }
                })
            }
        })
    }
    
    func tapped(state: DialogViewState) {
        // TODO handle mic button // print(t.view)
        let stt = self.getStt()
        if (stt.recognizing) {
            print("pause stt")
            stt.endRecognize()
            stt.paused = true
            stt.delegate?.showText(NSLocalizedString("PAUSING", comment:"Pausing"));
            stt.delegate?.inactive()
        } else if(stt.paused){
            print("restart stt")
            stt.restartRecognize()
            stt.delegate?.showText(NSLocalizedString("SPEAK_NOW", comment:"Speak Now!"));
            stt.delegate?.listen()
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
    
    var lastresponse:MessageResponse? = nil
    internal func newresponse(orgres: MessageResponse?){
        self.removeImageView()
        var resobj:MessageResponse? = orgres
        if resobj == nil{
            resobj = self.lastresponse
        }else{
            self.lastresponse = orgres
        }
        let restxt = resobj!.output.text.joinWithSeparator("\n")
        self.conv_context = resobj!.context

        var agent_name = "Cog"
        if let name:String = resobj!.context["agent_name"] as? String {
            agent_name = name
        }
        self.tableData.append(["name": agent_name, "type": 1,  "image": "conversation.png", "message": restxt])
        self.refreshTableView()
        var postEndDialog:((Void)->Void)? = nil
        if let fin:Bool = resobj!.context["finish"] as? Bool{ 
            if fin {
                postEndDialog = {
                    self.navigationController?.navigationBarHidden = false
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
                        postEndDialog = { [unowned self] in
                            self.navigationController?.navigationBarHidden = false
                            if self.root != nil {
                                self.navigationController?.popToViewController(self.root!, animated: true)
                            } else {
                                self.navigationController?.popToRootViewControllerAnimated(true)
                            }
                            UIApplication.sharedApplication().openURL(NSURL(string: self.conv_navigation_url + "?toID=" + nodes.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!)!, options: [:], completionHandler: nil)
                        }
                    }
                }
            }
        }
        var speech = restxt
        if let pron:String = resobj!.context["output_pron"] as? String {
            speech = pron
        }
        dispatch_async(dispatch_get_main_queue(), { [unowned self] in
            if let callback = postEndDialog {
                self.endDialog(speech)
                self._tts?.speak(speech) {
                    callback()
                }
            }else{
                self.startDialog(speech)
            }
        })
    }
    internal func newmessage(msg:String){
        self.tableData.append(["name":"myself", "type": 2,
            "message":msg ])
        self.refreshTableView()
    }
    
    internal func sendmessage(msg: String){
        if !msg.isEmpty{
            newmessage(msg)
        }

        let conversation = ConversationEx()
        if let context = self.conv_context {
            let ctxdic:NSMutableDictionary = NSMutableDictionary(dictionary: context)
            ctxdic.addEntriesFromDictionary(self.conv_context_local.getContext() as [NSObject : AnyObject])

            conversation.message(msg, server: self.conv_server!, api_key: self.conv_api_key!, client_id: self.conv_client_id, context: ctxdic, failure: self.failureCustom) { [unowned self] response in
                let conversationID = response.context["conversation_id"] as! String
                if conversationID != self.conversation_id{
                    self.conversation_id = conversationID
                    NSLog("conversationid changed: " + self.conversation_id!)
                }
                
                self.newresponse(response)
            }
        }else{
            conversation.message(msg, server: self.conv_server!, api_key: self.conv_api_key!, client_id: self.conv_client_id, context: self.conv_context_local.getContext(), failure: self.failureCustom) {[unowned self] response in
                self.newresponse(response)
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
            stt.listen([([".*"], {[unowned self] (str, dur) in self.dummy(str)})], selfvoice: speech!,speakendactions:[({[unowned self] str in self.endspeak(nil)})], avrdelegate: nil, failure:self.failureCustom)
        }else{
            if self._lastspeech != nil{
                self.newresponse(nil)
            }
        }
    }
    var _lastspeech:String? = nil
    func startDialog(response:String) {
        UIApplication.sharedApplication().idleTimerDisabled = true//reset sleep timer

        let stt:STTHelper = self.getStt()
        stt.endRecognize()
        stt.delegate = self.dialogViewHelper
        self._lastspeech = response

        stt.listen([([".*"], {[unowned self] (str, dur) in
            self.sendmessage(str)
        })], selfvoice: response,speakendactions:[({[unowned self] str in
            UIApplication.sharedApplication().idleTimerDisabled = false//enable sleep timer
            if let lastdata = self.tableData.last{
                if 3 == lastdata["type"] as! Int{
                    if self.tableView != nil{
                        let nos = self.tableView!.numberOfSections
                        let nor = self.tableView!.numberOfRowsInSection(nos-1)
                        if nor > 0{
                            let lastPath:NSIndexPath = NSIndexPath(forRow:nor-1, inSection:nos-1)
                            if let tablecell:CustomLeftTableViewCellSpeaking = self.tableView!.cellForRowAtIndexPath(lastPath) as? CustomLeftTableViewCellSpeaking{
                                tablecell.showAllText()
                            }
                        }
                    }
                    let nm = lastdata["name"]
                    let img = lastdata["image"]
                    let msg = lastdata["message"]
                    self.tableData.popLast()
                    self.tableData.append(["name": nm!, "type": 1, "image": img!, "message": msg!])
                }
            }
            self.endspeak(str)
        })], avrdelegate: nil, failure:self.failureCustom)
    }
    func endDialog(response:String){
        let stt:STTHelper = self.getStt()
        stt.endRecognize()
        stt.delegate = self.dialogViewHelper
        self._lastspeech = response
    }
    func failureCustom(error: NSError){
        NSLog("%@",error)
        let str = error.localizedDescription
        self.tableData.append(["name": "Error", "type": 1,  "image": "conversation.png", "message": str])
        self.refreshTableView()
        dispatch_async(dispatch_get_main_queue(), {[unowned self] in
            self.startDialog(str)
        })
    }
    func justSpeech(response: String){
        let stt:STTHelper = self.getStt()
        stt.endRecognize()
        stt.delegate = self.dialogViewHelper
        
        stt.listen([([".*"], {[unowned self] str in self.sendmessage("")})], selfvoice: response,speakendactions:[({[unowned self] str in self.endspeak(str)})], avrdelegate:nil, failure:self.failureCustom)
    }
}
