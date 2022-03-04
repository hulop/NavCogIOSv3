Pod::Spec.new do |s|
  s.name         = "picojson"
  s.version      = "1.3.0"
  s.summary      = "picojson"
  s.description  = <<-DESC
PicoJSON is a tiny JSON parser / serializer for C++
                   DESC
  s.homepage     = "https://github.com/kazuho/picojson"
  s.license      = { :type => "asis", :file => "LICENSE"}
  s.author       = "Kazuho Oku"
  s.source       = { :git => "https://github.com/kazuho/picojson.git", :tag => "v1.3.0" }
  s.source_files = "*.h"
  s.public_header_files = "*.h"
  s.ios.deployment_target = "9.0"
  s.osx.deployment_target = "10.6"

end
