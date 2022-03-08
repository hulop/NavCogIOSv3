Pod::Spec.new do |s|
  s.name         = "HLPLocationManager"
  s.version      = "1.1.1"
  s.summary      = "HLPLocationManager"
  s.description  = <<-DESC
HLPLocationManager is a BLE beacon-based localization Framework for iOS.
                   DESC
  s.homepage     = "https://github.com/hulop/HLPLocationManager"
  s.license      = { :type => "MIT", :file => "LICENSE"}
  s.author       = "HULOP"
  s.source       = { :git => "https://github.com/hulop/HLPLocationManager.git", :branch => "flat-build" }
  s.ios.source_files = "HLPLocationManager/*.{m,h,mm}"
  s.ios.preserve_paths = "HLPLocationManager/*.{m,h,mm}"
  s.ios.public_header_files = ""
  s.osx.source_files = "HLPLocationManager/HLPLocation.{m,h}"

  s.ios.deployment_target = "9.0"
  s.osx.deployment_target = "10.6"

  s.ios.dependency 'bleloc', '1.3.6'
  s.ios.dependency 'SSZipArchive', '2.4.2'

end
