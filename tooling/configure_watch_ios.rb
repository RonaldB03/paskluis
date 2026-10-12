# Run before pod install in WATCH_BETA=1 builds. Uses CocoaPods' xcodeproj gem.
# Re-running is safe. Production builds use the unchanged checked-in project.
require 'xcodeproj'
require 'fileutils'
abort 'Set WATCH_BETA=1 for the watch test build' unless ENV['WATCH_BETA'] == '1'
root = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(root, 'ios/Runner.xcodeproj'))
runner = project.targets.find { |t| t.name == 'Runner' }
runner_group = project.main_group.find_subpath('Runner', false)
%w[WatchBridge.swift PKGarminBridge.m PKGarminBridge.h].each do |name|
  ref = runner_group.files.find { |f| f.path == name } || runner_group.new_file(name)
  runner.source_build_phase.add_file_reference(ref, true) unless name.end_with?('.h')
end
pkg = project.root_object.package_references.find { |p| p.repositoryURL == 'https://github.com/garmin/connectiq-companion-app-sdk-ios.git' }
unless pkg
  pkg = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  pkg.repositoryURL = 'https://github.com/garmin/connectiq-companion-app-sdk-ios.git'
  pkg.requirement = { 'kind' => 'exactVersion', 'version' => '1.8.0' }
  project.root_object.package_references << pkg
end
unless runner.package_product_dependencies.any? { |p| p.product_name == 'ConnectIQ' }
  product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  product.package = pkg
  product.product_name = 'ConnectIQ'
  runner.package_product_dependencies << product
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.product_ref = product
  runner.frameworks_build_phase.files << build_file
end
watch = project.targets.find { |t| t.name == 'PasKluisWatch' }
unless watch
  watch = project.new_target(:application, 'PasKluisWatch', :watchos, '9.0')
  group = project.main_group.new_group('PasKluisWatch', 'PasKluisWatch')
  watch.source_build_phase.add_file_reference(group.new_file('PasKluisWatchApp.swift'))
  watch.resources_build_phase.add_file_reference(group.new_file('Assets.xcassets'))
  runner.add_dependency(watch)
  embed = runner.new_copy_files_build_phase('Embed Watch Content')
  embed.dst_subfolder_spec = '16'
  embed.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
  embed.add_file_reference(watch.product_reference, true).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end
# Flutter's Thin Binary phase reads the final app Info.plist. Embed the watch
# before that phase, otherwise Xcode detects a copy/Info.plist dependency cycle.
embed = runner.copy_files_build_phases.find { |phase| phase.name == 'Embed Watch Content' }
thin = runner.shell_script_build_phases.find { |phase| phase.name == 'Thin Binary' }
if embed && thin
  runner.build_phases.delete(embed)
  runner.build_phases.insert(runner.build_phases.index(thin), embed)
end
watch.build_configurations.each do |config|
  settings = config.build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'nl.paskluis.app.watchkitapp'
  settings['PRODUCT_NAME'] = 'PasKluisWatch'
  settings['SWIFT_VERSION'] = '5.0'
  settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'PasKluis'
  settings['INFOPLIST_KEY_WKApplication'] = 'YES'
  settings['INFOPLIST_KEY_WKCompanionAppBundleIdentifier'] = 'nl.paskluis.app'
  settings['INFOPLIST_KEY_WKRunsIndependentlyOfCompanionApp'] = 'NO'
  settings['INFOPLIST_KEY_ITSAppUsesNonExemptEncryption'] = 'NO'
  settings['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
  settings['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
  settings['TARGETED_DEVICE_FAMILY'] = '4'
  settings['SUPPORTED_PLATFORMS'] = 'watchos watchsimulator'
  settings['SDKROOT'] = 'watchos'
  settings['SKIP_INSTALL'] = 'YES'
  settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  phone_config = runner.build_configurations.find { |c| c.name == config.name }
  settings['DEVELOPMENT_TEAM'] = phone_config.build_settings['DEVELOPMENT_TEAM'] if phone_config
  # Flutter's generated versions must also reach the companion target.
  config.base_configuration_reference = project.files.find { |f| f.path == 'Flutter/Generated.xcconfig' }
end
runner.build_configurations.each do |config|
  config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = '$(inherited) WATCH_BETA'
  config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] = ['$(inherited)', 'WATCH_BETA=1']
end
info_path = File.join(root, 'ios/Runner/Info.plist')
info = Xcodeproj::Plist.read_from_path(info_path)
info['CFBundleURLTypes'] ||= []
unless info['CFBundleURLTypes'].any? { |t| (t['CFBundleURLSchemes'] || []).include?('paskluis-garmin') }
  info['CFBundleURLTypes'] << { 'CFBundleURLSchemes' => ['paskluis-garmin'], 'CFBundleTypeRole' => 'Editor' }
end
info['LSApplicationQueriesSchemes'] = ((info['LSApplicationQueriesSchemes'] || []) + ['gcm-ciq', 'gcm-ciq-install']).uniq
info['NSBluetoothAlwaysUsageDescription'] = 'PasKluis gebruikt Bluetooth om gekozen pasjes naar je Garmin-horloge te sturen.'
Xcodeproj::Plist.write_to_path(info, info_path)
project.save
puts 'Configured Apple Watch target and Garmin iPhone bridge (test build).'
