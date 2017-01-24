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
import Alamofire
import ConversationV1
import Freddy
import RestKit

public struct MessageResponse: JSONDecodable {// copied from original to keep consistency and to override context structure


    /// The user input from the request.
    public let input: InputData

    /// Information about the state of the conversation.
    public let context: NSDictionary

    /// An array of terms from the request that were identified as entities.
    public let entities: [Entity]

    /// An array of terms from the request that were identified as intents. The list is sorted in
    /// descending order of confidence. If there are 10 or fewer intents, the sum of the confidence
    /// values is 100%.
    public let intents: [Intent]

    /// An output object that includes the response to the user,
    /// the nodes that were hit, and messages from the log.
    public let output: OutputData

    /// Used internally to initialize a `MessageResponse` model from JSON.
    public init(json: JSON) throws {
        input = try json.decode("input")
        let jdic = try json.dictionary()
        let cdata = try jdic["context"]!.serialize()
        context = try NSJSONSerialization.JSONObjectWithData(cdata, options: NSJSONReadingOptions.MutableContainers) as! NSDictionary
        entities = try json.arrayOf("entities", type: Entity.self)
        intents = try json.arrayOf("intents",  type: Intent.self)
        output = try json.decode("output")
    }
}

class AlamofireManager {
    static let sharedInstance: Manager = {
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.HTTPAdditionalHeaders = Manager.defaultHTTPHeaders
        configuration.timeoutIntervalForRequest = 15
        return Manager(configuration: configuration)
    }()
}

public class ConversationEx {

    private let domain = "hulop.navcog.ConversationV1"
    static var running = false
    private func dataToError(data: NSData) -> NSError? {
        do {
            let json = try JSON(data: data)
            let error = try json.string("error")
            let code = (try? json.int("code")) ?? 400
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
    public func message(
        text: String? = nil,
        server: String,
        api_key: String,
        client_id: String? = nil,
        context: NSDictionary? = nil,
        failure: (NSError -> Void)? = nil,
        success: MessageResponse -> Void)
    {
        if ConversationEx.running {
            return
        }
        // construct query parameters
        var queryParameters = [NSURLQueryItem]()
        queryParameters.append(NSURLQueryItem(name: "lang", value: NSLocale.currentLocale().languageCode))
        queryParameters.append(NSURLQueryItem(name: "api_key", value: api_key))
        if text != nil {
            queryParameters.append(NSURLQueryItem(name: "text", value: text))
        }
        if client_id != nil {
            queryParameters.append(NSURLQueryItem(name: "id", value: client_id))
        }
        var json = [String: JSON]()
        if let context = context {
            let njsdata = try! NSJSONSerialization.dataWithJSONObject(context, options: [])
            json["context"] = try! Freddy.JSONParser.createJSONFromData(njsdata)
        }
        guard let body = try? JSON.Dictionary(json).serialize() else {
            let failureReason = "context could not be serialized to JSON."
            let userInfo = [NSLocalizedFailureReasonErrorKey: failureReason]
            let error = NSError(domain: domain, code: 0, userInfo: userInfo)
            failure?(error)
            return
        }

        // construct REST request
        let request = RestRequest(
            method: .POST,
            url: "https://" + server + "/service",
            acceptType: "application/json",
            contentType: "application/json",
            userAgent: "NavCogDialog",
            queryParameters: queryParameters,
            headerParameters: [:],
            messageBody: body)


        // execute REST request
        ConversationEx.running = true
        AlamofireManager.sharedInstance.request(request)
            .responseObject(dataToError: dataToError) {
                (response: Response<MessageResponse, NSError>) in
                ConversationEx.running = false
                switch response.result {
                case .Success(let response): success(response)
                case .Failure(let error): failure?(error)
                }
        }
    }
}
