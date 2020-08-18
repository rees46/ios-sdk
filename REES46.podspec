
Pod::Spec.new do |s|
  s.name             = 'REES46'
  s.version          = '1.0.7'
  s.summary          = 'REES46 iOS SDK: all-in-one marketing stack for eCommerce'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
This is iOS SDK for REES46 platform.
                       DESC

  s.homepage         = 'https://github.com/rees46/ios-sdk'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'REES46' => '«desk@rees46.com»' }

  s.source       = { :git => "https://github.com/rees46/ios-sdk.git", :branch => "master",
  :tag => s.version.to_s }


  s.ios.deployment_target = '9.3'

  s.source_files = 'REES46/Classes/**/*'
  s.swift_version = '5'
end
