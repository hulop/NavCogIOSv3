Pod::Spec.new do |s|
  s.name         = "cereal"
  s.version      = "1.1.2"
  s.summary      = "cereal"
  s.description  = <<-DESC
cereal is a header-only C++11 serialization library.
                   DESC
  s.homepage     = "https://github.com/USCiLab/cereal"
  s.license      = { :type => "BSD", :file => "LICENSE"}
  s.author       = "USCiLab"
  s.source       = { :git => "https://github.com/USCiLab/cereal.git", :tag => "v1.1.2" }
  s.source_files = "include/cereal/**/*.{h,hpp}"
  s.header_mappings_dir = "include"
  s.ios.deployment_target = "9.0"
  s.osx.deployment_target = "10.6"
end
