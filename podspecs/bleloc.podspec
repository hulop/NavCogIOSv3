Pod::Spec.new do |s|
  s.name         = "bleloc"
  s.version      = "1.3.6"
  s.summary      = "Localization library"
  s.description  = <<-DESC
This is a localization library for bluetooth le beacons.
                   DESC
  s.homepage     = "https://github.com/hulop/blelocpp"
  s.license      = { :type => "MIT", :file => "LICENSE"}
  s.author       = ""
  s.source       = { :git => "https://github.com/hulop/blelocpp.git", :tag => "v1.3.6" }
  s.source_files = ["ble-cpp/src/*/*.{cpp}", "bleloc/*.{h,hpp}"]
  s.public_header_files = "bleloc/*.{h,hpp}"
  s.header_mappings_dir = "."

  s.ios.deployment_target = "9.0"
  s.osx.deployment_target = "10.6"

  s.dependency 'OpenCV',   '4.5.3'
  s.dependency 'boost',    '1.61.0'
  s.dependency 'eigen',    '3.2.5'
  s.dependency 'picojson', '1.3.0'
  s.dependency 'cereal',   '1.1.2'

  s.xcconfig = {'GCC_SYMBOLS_PRIVATE_EXTERN' => true}

  s.prepare_command = <<-CMD
    mkdir bleloc
    cp ble-cpp/src/*/*.{h,hpp} bleloc
  CMD
end
