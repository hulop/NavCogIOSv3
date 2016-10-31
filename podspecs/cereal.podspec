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
  s.xcconfig     = { :HEADER_SEARCH_PATHS => "\"${PODS_ROOT}/cereal/include\""}
end
