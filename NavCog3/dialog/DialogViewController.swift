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
import RestKit
import AVFoundation
import ConversationV1


var standardError = FileHandle.standardError

extension FileHandle : TextOutputStream {
    public func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        self.write(data)
    }
}

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
        let notificationCenter = NotificationCenter.default
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
    
    fileprivate var _tts:TTSProtocol? = nil
    fileprivate var _stt:STTHelper? = nil
    
    let conv_devicetype:String = UIDevice.current.systemName + "_" + UIDevice.current.systemVersion
    let conv_deviceid:String = (UIDevice.current.identifierForVendor?.uuidString)!
    var conv_context:[String: Any]? = nil
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
    
    var tableData:[Dictionary<String,Any>]!
    var heightLeftCell: CustomLeftTableViewCell = CustomLeftTableViewCell()
    var heightRightCell: CustomRightTableViewCell = CustomRightTableViewCell()
    
    fileprivate var dialogViewHelper: DialogViewHelper = DialogViewHelper()
    var cancellable = false
    
    
    let ttslock:NSLock = NSLock()
    fileprivate func getTts() -> TTSProtocol{
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
    fileprivate func getStt() -> STTHelper{
        self.sttlock.lock()
        defer{self.sttlock.unlock()}
        if let stt = self._stt{
            return stt
        }else{
            self._stt = STTHelper()
            self._stt!.tts = self.getTts()
            self._stt!.prepare()
            self._stt!.useRawError = AuthManager.shared().isDeveloperAuthorized()
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
        _ = self.getStt()
        self.conv_context = nil
        self.tableData = []

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(resetConversation), name: NSNotification.Name(rawValue: "ResetConversation"), object: nil)
        nc.addObserver(self, selector: #selector(restartConversation), name: NSNotification.Name(rawValue: "RestartConversation"), object: nil)
        nc.addObserver(self, selector: #selector(pauseConversation), name: NSNotification.Name(rawValue: "PauseConversation"), object: nil)
        nc.addObserver(self, selector: #selector(requestDialogEnd), name: NSNotification.Name(rawValue: REQUEST_DIALOG_END), object: nil)
        nc.addObserver(self, selector: #selector(requestDialogAction), name: NSNotification.Name(rawValue: REQUEST_DIALOG_ACTION), object: nil)
    }
    
    internal func updateView() {
    }

    override func viewWillAppear(_ animated: Bool) {
        self.updateView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "RestartConversation"), object: self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "ResetConversation"), object: self)
        self.updateView()
    }
    
    internal func showNoSpeechRecoAlert() {
        let title = NSLocalizedString("NoSpeechRecoAccessAlertTitle", comment:"");
        let message = NSLocalizedString("NoSpeechRecoAccessAlertMessage", comment:"");
        let setting = NSLocalizedString("SETTING", comment:"");
        let cancel = NSLocalizedString("CANCEL", comment:"");
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: setting, style: UIAlertActionStyle.default, handler: { (action) in
            let url = URL(string:"App-Prefs:root=Privacy")
            UIApplication.shared.open(url!, options:[:], completionHandler: { (success) in
            })
        }))
        alert.addAction(UIAlertAction(title: cancel, style: UIAlertActionStyle.default, handler: { (action) in
        }))
        DispatchQueue.main.async(execute: {
            self.present(alert, animated: true, completion: {
            })
        })
        cancellable = true
        self.updateView()
        
        self.tableData.append(["name": NSLocalizedString("Error", comment:"") as AnyObject, "type": 1 as AnyObject,  "image": "conversation.png" as AnyObject, "message": message as AnyObject])
        self.refreshTableView()
    }
    
    internal func showNoAudioAccessAlert(){
        let title = NSLocalizedString("NoAudioAccessAlertTitle", comment:"");
        let message = NSLocalizedString("NoAudioAccessAlertMessage", comment:"");
        let setting = NSLocalizedString("SETTING", comment:"");
        let cancel = NSLocalizedString("CANCEL", comment:"");

        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: setting, style: UIAlertActionStyle.default, handler: { (action) in
            let url = URL(string:"App-Prefs:root=Privacy")
            UIApplication.shared.open(url!, options:[:], completionHandler: { (success) in
            })
        }))
        alert.addAction(UIAlertAction(title: cancel, style: UIAlertActionStyle.default, handler: { (action) in
        }))
        DispatchQueue.main.async(execute: {
            self.present(alert, animated: true, completion: { 
            })
        })
        cancellable = true
        self.updateView()
        
        self.tableData.append(["name": NSLocalizedString("Error", comment:"") as AnyObject, "type": 1 as AnyObject,  "image": "conversation.png" as AnyObject, "message": message as AnyObject])
        self.refreshTableView()
    }
    
    internal func requestDialogEnd() {
        if cancellable {
            _ = self.navigationController?.popToRootViewController(animated: true)
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
        DispatchQueue.main.async {
            self.conv_context_local.delegate = self
            self.getStt().prepare()
            self.initDialogView()
            self.conv_started = false
            self.startConversation()
        }
    }
    
    internal func pauseConversation() {
        let stt = self.getStt()
        if (stt.recognizing) {
            print("pause stt")
            stt.endRecognize()
            stt.paused = true
            stt.delegate?.showText(NSLocalizedString("PAUSING", comment:"Pausing"));
            stt.delegate?.inactive()
        } else if(stt.speaking) {
            print("stop tts")
            stt.speaking = false
            stt.tts?.stop() // do not use "true" flag beacus it causes no-speaking problem.
            stt.delegate?.showText(NSLocalizedString("PAUSING", comment:"Pausing"));
            stt.delegate?.inactive()
        }
    }
    
    internal func onContextChange(_ context:LocalContext){
        if !self.conv_started{
            self.conv_started = true
            self.sendmessage("")
        }
    }
    fileprivate func initConversationConfig(){
        let defs:NSDictionary = ServerConfig.shared().selectedServerConfig as NSDictionary;

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
        let str = NavDataStore.shared().userID!
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
    fileprivate func initDialogView(){
        self.view.backgroundColor = defbackgroundColor
       if(nil == self.tableView){
            // chat messages
            self.tableView = NoVoiceTableView()
            self.tableView!.register(CustomLeftTableViewCell.self, forCellReuseIdentifier: "CustomLeftTableViewCell")
            self.tableView!.register(CustomRightTableViewCell.self, forCellReuseIdentifier: "CustomRightTableViewCell")
            self.tableView!.register(CustomLeftTableViewCellSpeaking.self, forCellReuseIdentifier: "CustomLeftTableViewCellSpeaking")
            self.tableView!.delegate = self
            self.tableView!.dataSource = self
            self.tableView!.separatorColor = UIColor.clear
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
    
    fileprivate func resizeTableView(){
        if(nil == self.tableView){
            return
        }

        let statusBarHeight: CGFloat = UIApplication.shared.statusBarFrame.height + 40
        let txheight = self.dialogViewHelper.helperView.bounds.height + self.dialogViewHelper.label.bounds.height
        
        let displayWidth: CGFloat = self.view.frame.width
        let displayHeight: CGFloat = self.view.frame.height
        self.tableView!.frame = CGRect(x:0, y:statusBarHeight, width:displayWidth, height:displayHeight - statusBarHeight - txheight)
    }
    fileprivate func initImageView(){
        let image1:UIImage? = UIImage(named:"Dashboard.PNG")
        
        self.imageView = UIImageView(frame:self.view.bounds)
        self.imageView!.image = image1
        
        self.view.addSubview(self.imageView!)
    }
    fileprivate func removeImageView(){
        self.imageView?.removeFromSuperview()
    }
    override func viewDidLayoutSubviews() {
        self.resizeTableView()

    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
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
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        var type:Int = 1
        var data:[String:Any] = [:]
        if indexPath.row < self.tableData.count {
            data = self.tableData[indexPath.row]
            type = data["type"] as! Int
        }
        if 1 == type
        {
            let cell = tableView.dequeueReusableCell(withIdentifier: "CustomLeftTableViewCell", for: indexPath) as! CustomLeftTableViewCell
            cell.backgroundColor = defbackgroundColor
            cell.fillColor = white
            cell.fontColor = black
            cell.strokeColor = blue
            _ = cell.setData(tableView.frame.size.width - 20, data: data)
            return cell
        }
        else if 2 == type
        {
            let cell = tableView.dequeueReusableCell(withIdentifier: "CustomRightTableViewCell", for: indexPath) as! CustomRightTableViewCell
            cell.backgroundColor = defbackgroundColor
            cell.fillColor = blue
            cell.fontColor = white
            cell.strokeColor = blue
            _ = cell.setData(tableView.frame.size.width - 20, data: data)
            return cell
        }else{
            let cell = tableView.dequeueReusableCell(withIdentifier: "CustomLeftTableViewCellSpeaking", for: indexPath) as! CustomLeftTableViewCellSpeaking
            cell.backgroundColor = defbackgroundColor
            cell.fillColor = white
            cell.fontColor = black
            cell.strokeColor = blue
            _ = cell.setData(tableView.frame.size.width - 20, data: data)
            return cell
        }
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData.count
    }
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    internal func refreshTableView(_ dontscroll:Bool? = false){
        if(nil == self.tableView){
            return
        }
        DispatchQueue.main.async(execute: { [weak self] in
            if let weakself = self {
                weakself.tableView?.reloadData()
                if !dontscroll!{
                    DispatchQueue.main.async(execute: {
                        if(nil == weakself.tableView){
                            return
                        }
                        let nos = weakself.tableView!.numberOfSections
                        let nor = weakself.tableView!.numberOfRows(inSection: nos-1)
                        if nor > 0{
                            let lastPath:IndexPath = IndexPath(row:nor-1, section:nos-1)
                            weakself.tableView!.scrollToRow( at: lastPath , at: .bottom, animated: true)
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
    
    internal func matches(_ txt: String, pattern:String)->[[String]]{
        let nsstr = txt as NSString
        var ret:[[String]] = []
        if let regex = try? NSRegularExpression(pattern: pattern, options:NSRegularExpression.Options()){
            let result = regex.matches(in: nsstr as String, options: NSRegularExpression.MatchingOptions(), range: NSMakeRange(0, nsstr.length)) 
            if 0 < result.count{
                for i in 0 ..< result.count {
                    var temp: [String] = []
                    for j in 0 ..< result[i].numberOfRanges{
                        temp.append(nsstr.substring(with: result[i].rangeAt(j)))
                    }
                    ret.append(temp)
                }
            }
        }
        return ret
    }
    
    internal func _setTimeout(_ delay:TimeInterval, block:@escaping ()->Void) -> Timer {
        return Timer.scheduledTimer(timeInterval: delay, target: BlockOperation(block: block), selector: #selector(Operation.main), userInfo: nil, repeats: false)
    }

    var inflight:Timer? = nil
    var agent_name = ""
    var lastresponse:MessageResponse? = nil
    internal func newresponse(_ orgres: MessageResponse?){
        conv_context_local.welcome_shown()
        DispatchQueue.main.async(execute: { [weak self] in
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
        let restxt = resobj!.output.text.joined(separator: "\n")
        self.conv_context = resobj!.context
        
        guard let cc = self.conv_context else {
            return
        }

        guard let system:[String:Any] = cc["system"] as? [String:Any] else {
            return
        }
        
        guard let dialog_request_counter:Int = system["dialog_request_counter"] as? Int else {
            return
        }
        if dialog_request_counter > 1 {
            self.timeoutCount = 0
        }

        if let name:String = cc["agent_name"] as? String {
            agent_name = name
        }
        
        self.removeWaiting()
        self.tableData.append(["name": agent_name, "type": 1,  "image": "conversation.png", "message": restxt])
        self.refreshTableView()
        var postEndDialog:((Void)->Void)? = nil
        if let fin:Bool = cc["finish"] as? Bool{
            if fin {
                postEndDialog = {
                    self.cancellable = true
                    self.updateView()

                    if self.root != nil {
                        _ = self.navigationController?.popToViewController(self.root!, animated: true)
                    } else {
                        _ = self.navigationController?.popToRootViewController(animated: true)
                    }
                    //UIApplication.shared.open(URL(string: self.conv_navigation_url + "")!, options: [:], completionHandler: nil)                    
                }
            }
        }
        if let navi:Bool = cc["navi"] as? Bool{
            if navi{
                if let dest_info:[String:Any] = cc["dest_info"] as! [String:Any]? {
                    if let nodes:String = dest_info["nodes"] as? String {
                        var info:[String : Any] = ["toID": nodes]
                        if cc["use_stair"] != nil {
                            info["use_stair"] = cc["use_stair"] as! Bool;
                        }
                        if cc["use_elevator"] != nil {
                            info["use_elevator"] = cc["use_elevator"] as! Bool;
                        }
                        
                        postEndDialog = { [weak self] in
                            if let weakself = self {
                                weakself.cancellable = true
                                weakself.updateView()
                                
                                if weakself.root != nil {
                                    _ = weakself.navigationController?.popToViewController(weakself.root!, animated: true)
                                } else {
                                    _ = weakself.navigationController?.popToRootViewController(animated: true)
                                }                                
                                
                                NotificationCenter.default.post(name: Notification.Name(rawValue:"request_start_navigation"),
                                                                object: weakself, userInfo: info)
                            }
                        }
                    }
                }
            }
        }
        var speech = restxt
        if let pron:String = cc["output_pron"] as? String {
            speech = pron
        }

        DispatchQueue.main.async(execute: { [weak self] in
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
    internal func newmessage(_ msg:String){
        self.tableData.append(["name":"myself" as AnyObject, "type": 2 as AnyObject,
            "message":msg as AnyObject ])
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
        sendTimeout = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true, block: { (timer) in
            DispatchQueue.main.async {
                let str = table[self.sendTimeoutCount%table.count]
                self.sendTimeoutCount = self.sendTimeoutCount + 1
                if (self.sendTimeoutCount > 1) {
                    _ = self.tableData.popLast()
                }
                self.tableData.append(["name": self.agent_name as AnyObject, "type": 1 as AnyObject,  "waiting":true as AnyObject, "image": "conversation.png" as AnyObject, "message": str as AnyObject])
                self.refreshTableView()
            }
        })
    }
    
    var sendTimeout:Timer? = nil
    var sendTimeoutCount = 0
    
    internal func sendmessage(_ msg: String, notimeout: Bool = false){
        if !msg.isEmpty{
            newmessage(msg)

            NavSound.sharedInstance().vibrate(nil)
            NavSound.sharedInstance().playVoiceRecoEnd()
        }

        let conversation = ConversationEx()
        if var context = self.conv_context {
            self.conv_context_local.getContext().forEach({ (key: String, value: Any) in
                context[key] = value
            })

            conversation.message(msg, server: self.conv_server!, api_key: self.conv_api_key!, client_id: self.conv_client_id, context: context, failure: { [weak self] (error:Error) in
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
            conversation.message(msg, server: self.conv_server!, api_key: self.conv_api_key!, client_id: self.conv_client_id, context: self.conv_context_local.getContext(), failure: { [weak self] (error:Error) in
                if let weakself = self {
                    weakself.removeWaiting()
                    weakself.failureCustom(error)
                }
            }) {[weak self] response in
                if let weakself = self {
                    weakself.removeWaiting()
                    weakself.newresponse(response)
                }
            }
        }
        if notimeout == false {
            DispatchQueue.main.async {
                self.showWaiting()
            }
        }
    }
    internal func endspeak(_ rsp:String?){
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
    func dummy(_ msg:String){
        //nop
    }

    func headupDialog(_ speech: String?) {
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
    func startDialog(_ response:String) {
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
                            let nor = weakself.tableView!.numberOfRows(inSection: nos-1)
                            if nor > 0{
                                let lastPath:IndexPath = IndexPath(row:nor-1, section:nos-1)
                                if let tablecell:CustomLeftTableViewCellSpeaking = weakself.tableView!.cellForRow(at: lastPath) as? CustomLeftTableViewCellSpeaking{
                                    tablecell.showAllText()
                                }
                            }
                        }
                        let nm = lastdata["name"]
                        let img = lastdata["image"]
                        let msg = lastdata["message"]
                        weakself.tableData.removeLast()
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
    
    func endDialog(_ response:String){
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
    func failureCustom(_ error: Error){
        print(error, to:&standardError)
        let str = error.localizedDescription
        self.removeWaiting()
        self.tableData.append(["name": NSLocalizedString("Error", comment:"") as AnyObject, "type": 1 as AnyObject,  "image": "conversation.png" as AnyObject, "message": str as AnyObject])
        self.refreshTableView()
        DispatchQueue.main.async(execute: { [weak self] in
            if let weakself = self {
                weakself.failDialog()
                weakself._tts?.speak(str) {
                }
            }
            })
        DispatchQueue.main.async(execute: { [weak self] in
            if let weakself = self {
                weakself.cancellable = true
                weakself.updateView()
            }
        })
    }
    
    var timeoutCount = 0
    
    func timeoutCustom(){
        if timeoutCount >= 0 { // temporary fix
            let str = NSLocalizedString("WAIT_ACTION", comment:"")
            self.tableData.append(["name": self.agent_name as AnyObject, "type": 1 as AnyObject,  "image": "conversation.png" as AnyObject, "message": str as AnyObject])
            self.refreshTableView()
            self.failDialog()
            self._tts?.speak(str) {
            }
            return
        }
        
        self.sendmessage("", notimeout: true)
        timeoutCount = timeoutCount + 1
    }
    
    func justSpeech(_ response: String){
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

