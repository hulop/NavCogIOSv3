//
//
//  ImageAdaptor.swift
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

/**
 Instantiate it for UIImage usage
 */
class ImageAdaptor {
    
    private let img : UIImage?
    
    init(img: UIImage? = nil) {
        self.img = img
    }
    
    /**
     Adjust the size the fit the screen
     
     - Parameters:
     - viewSize: Size of the UIView that uses the UIImage
     - frameWidth: Width of the outter frame
     - imageSize: Size of the UIImage
     */
    public func scaleImage(viewSize: CGSize, frameWidth: CGFloat, imageSize: CGSize? = nil) -> CGSize {
        guard let imgSize = img?.size ?? imageSize else { return .zero }
        
        let targetSize = CGSize(width: frameWidth,
                                height: frameWidth * (viewSize.height / viewSize.width))
        
        let widthScaleRatio = targetSize.width / imgSize.width
        let heightScaleRatio = targetSize.height / imgSize.height
        let factor = min(widthScaleRatio, heightScaleRatio)
        return CGSize(width: imgSize.width * factor,
                      height: imgSize.height * factor)
    }
    
}
