project 'NavCog3'
inhibit_all_warnings!

target 'NavCog3' do
  platform :ios, '8.4'
  pod 'OpenCV', '2.4.9'
  pod 'FormatterKit', '1.8.2'
  pod 'eigen', '3.2.5'
  pod 'bleloc', :podspec => "https://raw.githubusercontent.com/hulop/blelocpp/v1.2.6/bleloc.podspec"
#  pod 'bleloc', :path => "../blelocpp"
  pod 'boost', :podspec => './podspecs/boost.podspec.json'
  pod 'cereal', :podspec => './podspecs/cereal.podspec'
  pod 'picojson', :podspec => './podspecs/picojson.podspec'
  pod 'Mantle', '2.0.7'
  pod 'HLPWebView', :path => '../HLPWebView'
  pod 'HLPLocationManager', :path => '../HLPLocationManager'
end

target 'NavCogTool' do
  platform :osx, '10.10'
  pod 'FormatterKit', '1.8.2'
  pod 'Mantle', '2.0.7'
  pod 'HLPLocationManager', :path => '../HLPLocationManager'
end

target 'NavCogFingerPrint' do
  platform :ios, '8.4'
  pod 'Mantle', '2.0.7'
  pod 'HLPWebView', :path => '../HLPWebView'
  pod 'HLPLocationManager', :path => '../HLPLocationManager'
end
