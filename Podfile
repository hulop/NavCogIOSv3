project 'NavCog3'
inhibit_all_warnings!

target 'NavCog3' do
  platform :ios, '8.4'
  pod 'OpenCV', '2.4.9'
  pod 'eigen', '3.2.5'
  pod 'bleloc', :podspec => "https://raw.githubusercontent.com/hulop/blelocpp/v1.2.7/bleloc.podspec"
#  pod 'bleloc', :path => "../blelocpp"
  pod 'boost', :podspec => './podspecs/boost.podspec.json'
  pod 'cereal', :podspec => './podspecs/cereal.podspec'
  pod 'picojson', :podspec => './podspecs/picojson.podspec'
  pod 'HLPLocationManager', :path => '../HLPLocationManager'
end

target 'NavCogTool' do
  platform :osx, '10.10'
  pod 'HLPLocationManager', :path => '../HLPLocationManager'
end

target 'NavCogFingerPrint' do
  platform :ios, '8.4'
  pod 'HLPLocationManager', :path => '../HLPLocationManager'
end
