Pod::Spec.new do |s|
  s.name             = 'REES46'
  s.version          = '3.1.2'
  s.summary          = 'iOS SDK for REES46 platform — the wide toolset for ecommerce apps. You can integrate all REES46 tools into your iOS app.'

  s.description      = <<-DESC
  This is the iOS SDK for REES46 platform — the wide toolset for ecommerce apps:

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
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'REES46' => '«desk@rees46.com»' }

  s.screenshots = ['https://rees46.com/static-images/cocoapods/r46_ios_sdk_cocoapods_cover.png']

  s.source       = { :git => "https://github.com/rees46/ios-sdk.git", :branch => "master",
  :tag => s.version.to_s }


  s.ios.deployment_target = '9.3'

  s.source_files = 'REES46/Classes/**/*'
  s.swift_version = '5'
end
