version_file = File.join(File.dirname(__FILE__), 'version.properties')
version = File.read(version_file).match(/VERSION_NAME=(.+)/)[1].strip

Pod::Spec.new do |s|
  s.name             = 'REES46'
  s.version          = version

  s.summary          = 'REES46 SDK for iOS platform - the wide toolset for eCommerce apps. This SDK can be used to integrate in your own app for iOS in few steps.'
  s.readme           = 'https://reference.api.rees46.com/#{spec.version.to_s}/README.md'

  s.description      = <<-DESC
  REES46 SDK for iOS platform - the wide toolset for eCommerce apps:

  - Personalization engine.
  - Product recommendations.
  - Personalized products search engine.
  - Bulk emails, push-notifications, SMS and Telegram messages.
  - Transactional emails, push-notifications, Telegram and SMS.
  - Drip campaigns (email, push, Telegram, SMS).
  - Customizable on-site popups.
  - CRM, CDP and customer segments.
  - Net Promoter Score tool for any goal.
  - Stories.
  - In-app push.
  - Loyalty program.

  You can integrate all REES46 tools into your iOS app.
                       DESC


  s.homepage         = 'https://reference.api.rees46.com/'
  s.social_media_url = 'https://rees46.com/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'REES46' => '«desk@rees46.com»' }

  s.screenshots = ['https://rees46.com/static-images/cocoapods/r46_ios_sdk_cocoapods_cover.png']

  s.source           = { :git => "https://github.com/rees46/ios-sdk.git", :branch => "master" }

  s.ios.deployment_target = '12.0'

  s.source_files     = 'REES46/Classes/**/*.{swift}'
  s.resources        = 'REES46/Classes/Resources/*.{xcassets,xib,storyboard,json,png}'

  s.swift_version = '5'

end
