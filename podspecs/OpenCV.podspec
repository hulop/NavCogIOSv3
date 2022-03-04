Pod::Spec.new do |s|
    s.name         = "OpenCV"
    s.version      = "4.5.3"
    s.summary      = "OpenCV (Computer Vision) for iOS."
    s.description = "## OpenCV: Open Source Computer Vision Library\n### Resources\n* Homepage: <https://opencv.org>\n* Docs: <https://docs.opencv.org/master/>\n* Q&A forum: <http://answers.opencv.org>\n* Issue tracking: <https://github.com/opencv/opencv/issues>\n### Contributing\nPlease read the [contribution guidelines](https://github.com/opencv/opencv/wiki/How_to_contribute) before starting work on a pull request.\n#### Summary of the guidelines:\n* One pull request per issue;\n* Choose the right base branch;\n* Include tests and documentation;\n* Clean up \"oops\" commits before submitting;\n* Follow the [coding style guide](https://github.com/opencv/opencv/wiki/Coding_Style_Guide)."
    s.homepage     = "http://opencv.org"
    s.license = {
        :type => "3-clause BSD",
        :text => "                       By downloading, copying, installing or using the software you agree to this license.\n                       If you do not agree to this license, do not download, install,\n                       copy or use the software.\n                                                 License Agreement\n                                     For Open Source Computer Vision Library\n                                             (3-clause BSD License)\n                       Copyright (C) 2000-2020, Intel Corporation, all rights reserved.\n                       Copyright (C) 2009-2011, Willow Garage Inc., all rights reserved.\n                       Copyright (C) 2009-2016, NVIDIA Corporation, all rights reserved.\n                       Copyright (C) 2010-2013, Advanced Micro Devices, Inc., all rights reserved.\n                       Copyright (C) 2015-2016, OpenCV Foundation, all rights reserved.\n                       Copyright (C) 2015-2016, Itseez Inc., all rights reserved.\n                       Copyright (C) 2019-2020, Xperience AI, all rights reserved.\n                       Third party copyrights are property of their respective owners.\n                       Redistribution and use in source and binary forms, with or without modification,\n                       are permitted provided that the following conditions are met:\n                         * Redistributions of source code must retain the above copyright notice,\n                           this list of conditions and the following disclaimer.\n                         * Redistributions in binary form must reproduce the above copyright notice,\n                           this list of conditions and the following disclaimer in the documentation\n                           and/or other materials provided with the distribution.\n                         * Neither the names of the copyright holders nor the names of the contributors\n                           may be used to endorse or promote products derived from this software\n                           without specific prior written permission.\n                       This software is provided by the copyright holders and contributors \"as is\" and\n                       any express or implied warranties, including, but not limited to, the implied\n                       warranties of merchantability and fitness for a particular purpose are disclaimed.\n                       In no event shall copyright holders or contributors be liable for any direct,\n                       indirect, incidental, special, exemplary, or consequential damages\n                       (including, but not limited to, procurement of substitute goods or services;\n                       loss of use, data, or profits; or business interruption) however caused\n                       and on any theory of liability, whether in contract, strict liability,\n                       or tort (including negligence or otherwise) arising in any way out of\n                       the use of this software, even if advised of the possibility of such damage.\n"
    }
    s.author = "https://github.com/opencv/opencv/graphs/contributors"
    s.documentation_url = "https://docs.opencv.org/master/"
    s.source       = {
        :http => "https://github.com/younata/opencv-xcframework/releases/download/4.5.3/opencv2.xcframework.zip"
    }
    s.vendored_frameworks = "opencv2.xcframework"
    s.static_framework = true
#    s.platform = :ios
    s.swift_version = '5.0'
    s.ios.deployment_target  = '9.0'
    s.osx.deployment_target = '10.10'
    s.ios.frameworks = "Accelerate",
    "AssetsLibrary",
    "AVFoundation",
    "CoreGraphics",
    "CoreImage",
    "CoreMedia",
    "CoreVideo",
    "Foundation",
    "QuartzCore",
    "UIKit"
    s.preserve_paths = "opencv2.xcframework"
    s.source_files = "opencv2.xcframework/ios-arm64_armv7/opencv2.framework/Versions/A/Headers/**/*{.h,.hpp}"
    s.public_header_files = "opencv2.xcframework/ios-arm64_armv7/opencv2.framework/Versions/A/Headers/**/*{.h,.hpp}"
    s.header_mappings_dir = "opencv2.xcframework/ios-arm64_armv7/opencv2.framework/Versions/A/Headers/"
    s.header_dir = "opencv2"
    s.libraries = "stdc++"
    s.requires_arc = false
end

=begin
  "license": {
    "type": 
    "text": 
  },
  "authors": 
  "source": {
    "http": 
  },
  "platforms": {
      "ios": "9.0"
  },

  "vendored_frameworks": "opencv2.xcframework",
  "frameworks": [
  ],
}
=end