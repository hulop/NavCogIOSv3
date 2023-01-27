//
//  BaseWebView.swift
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

import UIKit

protocol WebAccessibilityDelegate {
    func onFinished()
}

/**
 The parent view implemented with WKNavigationDelegate
 */
class BaseWebView: BaseView, WKNavigationDelegate {

    let webView = WKWebView()
    private let lblLoading = UILabel()

    private var isLoadingFailed = false

    var accessibilityDelegate: WebAccessibilityDelegate?

    override func setup() {
        super.setup()

        webView.navigationDelegate = self
        addSubview(webView)

        // Display: Loading
        lblLoading.lineBreakMode = .byWordWrapping
        lblLoading.textAlignment = .center
        lblLoading.numberOfLines = 0
        lblLoading.font = .preferredFont(forTextStyle: .headline)
        addSubview(lblLoading)
    }

    // MARK: Layout
    override func layoutSubviews() {
        // Loading
        lblLoading.frame.size.width = self.frame.width
        lblLoading.frame.size.height = self.frame.height
        lblLoading.center = self.center
    }

    // MARK: Public Customized Functions
    public func loadContent(_ address: String) {
        let url = URL(string: address)
        let req = URLRequest(url: url!)
        webView.load(req)
    }

    public func loadDetail(html: String) {
        webView.loadHTMLString(html, baseURL: nil)
    }

    // MARK: WKNavigationDelegate
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        lblLoading.text = NSLocalizedString("web_loading", comment: "")
        lblLoading.sizeToFit()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        lblLoading.text = NSLocalizedString("web_failed", comment: "")
        lblLoading.sizeToFit()
        isLoadingFailed = true
        webView.isHidden = true
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard let response = navigationResponse.response as? HTTPURLResponse else { return }
        switch response.statusCode {
        case 200:
            let jsClearHeader = "document.getElementsByTagName('header')[0].innerHTML = '';"
            let jsClearFooter = "document.getElementsByTagName('footer')[0].innerHTML = '';"
            let js = "\(jsClearHeader)\(jsClearFooter)"
            webView.evaluateJavaScript(js, completionHandler: {(html, err) in
                if let e = err {
                    print(e.localizedDescription)
                }
            })
            decisionHandler(.allow)
        case 404:
            decisionHandler(.cancel)
        default:
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        lblLoading.isHidden = !isLoadingFailed
        lblLoading.accessibilityElementsHidden = !isLoadingFailed
        accessibilityDelegate?.onFinished()
    }
}
