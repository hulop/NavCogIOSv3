//
//
//  HTTPAdaptor.swift
//  NavCogMiraikan
//
/*******************************************************************************
 * Copyright (c) 2021 © Miraikan - The National Museum of Emerging Science and Innovation  
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

enum HttpMethod : String {
    case GET
    case POST
    case PUT
    case DELETE
}

/**
 Instantiate it for HTTP requests
 */
class HTTPAdaptor {
    
    /**
     HTTP Request
     
     - Parameters:
     - host: The server host
     - endpoint:The URL for specific action
     - params: The parameters in URL
     - headers: The request headers
     - body: The data content to be posted
     - success: The action after successful request
     - fail: The action after request failure
     */
    public func http(host: String = Host.miraikan.address,
                     endpoint: String,
                     params: [URLQueryItem]? = nil,
                     method: HttpMethod = .GET,
                     headers: [String: String]? = nil,
                     body: Data? = nil,
                     success: ((Data)->())?,
                     fail: (()->())? = nil) {
        var url = URLComponents(string: "\(host)\(endpoint)")!
        var req = URLRequest(url: url.url!)
        
        if let items = params {
            url.queryItems = items
        }
          
        req.httpMethod = method.rawValue
          
        if let b = body {
            req.httpBody = b
        }
          
        if let h = headers {
            req.allHTTPHeaderFields = h
        }
          
        URLSession.shared.dataTask(with: req) { (data, res, err) in
            if let _err = err,
               let _f = fail {
                print(_err.localizedDescription)
                DispatchQueue.main.async { _f() }
            }
            
            if let _data = data,
               let _f = success {
                DispatchQueue.main.async { _f(_data) }
            }
        }.resume()
    }
}
