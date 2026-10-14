require 'xcodeproj'
require 'fileutils'
root = File.expand_path('..', __dir__)
out = File.join(root, 'build/apple-store-preview')
FileUtils.mkdir_p(out)
FileUtils.cp_r(File.join(root, 'ios/PasKluisWatch/Assets.xcassets'), out)
source = File.read(File.join(root, 'ios/PasKluisWatch/PasKluisWatchApp.swift'))
# Only this simulator copy receives fictitious cards. Release sources stay unchanged.
source = source.sub("        super.init()", <<~SWIFT)
        super.init()
        snapshot = WatchSnapshot(schema: 1, owner: "store-preview", revision: 1, language: "nl", cards: [
          WatchCard(id: "demo-ah", name: "Albert Heijn", code: "DEMO", favorite: false, width: 4, height: 1, bits: "a"),
          WatchCard(id: "demo-gall", name: "Gall & Gall", code: "DEMO", favorite: false, width: 4, height: 1, bits: "a"),
          WatchCard(id: "demo-sligro", name: "Sligro", code: "DEMO", favorite: false, width: 4, height: 1, bits: "a")
        ])
        return
SWIFT
File.write(File.join(out, 'PasKluisWatchApp.swift'), source)
project = Xcodeproj::Project.new(File.join(out, 'Preview.xcodeproj'))
target = project.new_target(:application, 'PasKluisWatch', :watchos, '9.0')
target.source_build_phase.add_file_reference(project.main_group.new_file('PasKluisWatchApp.swift'))
target.resources_build_phase.add_file_reference(project.main_group.new_file('Assets.xcassets'))
target.build_configurations.each do |config|
  config.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER'=>'nl.paskluis.storepreview', 'SWIFT_VERSION'=>'5.0',
    'GENERATE_INFOPLIST_FILE'=>'YES', 'INFOPLIST_KEY_CFBundleDisplayName'=>'PasKluis',
    'INFOPLIST_KEY_WKApplication'=>'YES',
    'INFOPLIST_KEY_WKWatchOnly'=>'YES',
    'TARGETED_DEVICE_FAMILY'=>'4', 'MARKETING_VERSION'=>'1.9.2', 'CURRENT_PROJECT_VERSION'=>'153',
    'ASSETCATALOG_COMPILER_APPICON_NAME'=>'AppIcon', 'CODE_SIGNING_ALLOWED'=>'NO'
  })
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.set_launch_target(target)
scheme.save_as(project.path, 'PasKluisWatch')
