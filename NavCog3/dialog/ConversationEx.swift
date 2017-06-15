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
import ConversationV1
import RestKit

public struct MessageResponse: JSONDecodable {// copied from original to keep consistency
    
    /// The raw JSON object used to construct this model.
    public let json: [String: Any]
    
    /// The user input from the request.
    public let input: Input?
    
    /// Whether to return more than one intent.
    /// Included in the response only when sent with the request.
    public let alternateIntents: Bool?
    
    /// Information about the state of the conversation.
    public let context: [String: Any]
    
    /// An array of terms from the request that were identified as entities.
    /// The array is empty if no entities were identified.
    public let entities: [Entity]
    
    /// An array of terms from the request that were identified as intents. Each intent has an
    /// associated confidence. The list is sorted in descending order of confidence. If there are
    /// 10 or fewer intents then the sum of the confidence values is 100%. The array is empty if
    /// no intents were identified.
    public let intents: [Intent]
    
    /// An output object that includes the response to the user,
    /// the nodes that were hit, and messages from the log.
    public let output: Output
    
    /// Used internally to initialize a `MessageResponse` model from JSON.
    public init(json: JSON) throws {
        self.json = try json.getDictionaryObject()
        input = try? json.decode(at: "input")
        alternateIntents = try? json.getBool(at: "alternate_intents")
        let cdata:Context = try json.decode(at: "context")
        context = cdata.json
        entities = try json.decodedArray(at: "entities", type: Entity.self)
        intents = try json.decodedArray(at: "intents",  type: Intent.self)
        output = try json.decode(at: "output")
    }
}


open class ConversationEx {

    fileprivate let domain = "hulop.navcog.ConversationV1"
    static var running = false
    fileprivate func dataToError(_ data: Data) -> NSError? {
        do {
            let json = try JSON(data: data)
            let error = try json.getString(at: "error")
            let code = (try? json.getInt(at: "code")) ?? 400
            let userInfo = [NSLocalizedFailureReasonErrorKey: error]
            return NSError(domain: domain, code: code, userInfo: userInfo)
        } catch {
            return nil
        }
    }
    /**
     Start a new conversation or get a response to a user's input.

     - parameter text: The user's input message.
     - parameter failure: A function executed if an error occurs.
     - parameter success: A function executed with the conversation service's response.
     */
    open func message(
        _ text: String? = nil,
        server: String,
        api_key: String,
        client_id: String? = nil,
        context: [String: Any]? = nil,
        failure: ((Error) -> Void)? = nil,
        success: @escaping (MessageResponse) -> Void)
    {
        if ConversationEx.running {
            return
        }
        // construct query parameters
        var queryParameters = [URLQueryItem]()
        queryParameters.append(URLQueryItem(name: "lang", value: (Locale.current as NSLocale).languageCode))
        queryParameters.append(URLQueryItem(name: "api_key", value: api_key))
        if text != nil {
            queryParameters.append(URLQueryItem(name: "text", value: text))
        }
        if client_id != nil {
            queryParameters.append(URLQueryItem(name: "id", value: client_id))
        }
        var json = [String: Any]()
        if let context = context {
            let njsdata = try! JSONSerialization.data(withJSONObject: context, options: [])
            json["context"] = try! JSONSerialization.jsonObject(with: njsdata, options: [])
        }
        guard let body = try? JSON(dictionary: json).serialize() else {
            let failureReason = "context could not be serialized to JSON."
            let userInfo = [NSLocalizedFailureReasonErrorKey: failureReason]
            let error = NSError(domain: domain, code: 0, userInfo: userInfo)
            failure?(error)
            return
        }
        
        let ud = UserDefaults.standard
        let https = ud.bool(forKey: "https_connection") ? "https" : "http"

        // construct REST request
        let request = RestRequest(
            method: "POST",
            url: https + "://" + server + "/service",
            //userAgent: "NavCogDialog",
            credentials: Credentials.apiKey,
            headerParameters: [:],
            acceptType: "application/json",
            contentType: "application/json",
            queryItems: queryParameters,
            messageBody: body)


        // execute REST request
        ConversationEx.running = true
        
        request.responseData { (response) in
            ConversationEx.running = false
            do {
                switch response.result {
                case .success(let data):
                    let json = try MessageResponse(json: JSON(data:data))
                    success(json)
                    break
                case .failure(_):
                    let domain = "swift.conversationex"
                    let code = -1
                    let message = NSLocalizedString("checkNetworkConnection", comment:"")
                    let userInfo = [NSLocalizedDescriptionKey:message]
                    failure?(NSError(domain:domain, code: code, userInfo:userInfo))
                }
            } catch (let e){
                print(e)
                
                let domain = "swift.conversationex"
                let code = -1
                let message = e.localizedDescription
                let userInfo = [NSLocalizedDescriptionKey:message]
                failure?(NSError(domain:domain, code: code, userInfo:userInfo))
            }
        }
    }
}
