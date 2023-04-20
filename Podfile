use_frameworks!

MAC_TARGET_VERSION = '10.12'
IOS_TARGET_VERSION = '13'

def mac_pods
    pod 'MASShortcut', :git => 'https://github.com/glushchenko/MASShortcut.git', :branch => 'master'
end

def ios_pods
    pod 'NightNight', :git => 'https://github.com/glushchenko/NightNight.git', :branch => 'master'
    pod 'DKImagePickerController', '4.3.1'
    pod 'SSZipArchive', :git => 'https://github.com/glushchenko/ZipArchive.git', :branch => 'master'
    pod 'DropDown', '2.3.13'
    pod 'SwipeCellKit', :git => 'https://github.com/glushchenko/SwipeCellKit.git', :branch => 'develop'
    pod 'CropViewController'
end

def common_pods
    pod 'Highlightr', :git => 'https://github.com/glushchenko/Highlightr.git', :branch => 'master'
    pod 'libcmark_gfm', :git => 'https://github.com/glushchenko/libcmark_gfm', :branch => 'master' 
    pod 'RNCryptor', '~> 5.1.0'
    pod 'SSZipArchive', :git => 'https://github.com/glushchenko/ZipArchive.git', :branch => 'master'
    pod 'Punycode'
end

def framework_pods
    pod 'SwiftLint', '~> 0.30.0'
end

target 'FSNotesCore macOS' do
    platform :osx, MAC_TARGET_VERSION
    pod 'MASShortcut', :git => 'https://github.com/glushchenko/MASShortcut.git', :branch => 'master'
    framework_pods
end

target 'FSNotes' do
    platform :osx, MAC_TARGET_VERSION

    mac_pods
    common_pods
end

target 'FSNotes (iCloud Documents)' do
    platform :osx, MAC_TARGET_VERSION

    mac_pods
    common_pods
end

target 'FSNotes (Notarized)' do
  platform :osx, MAC_TARGET_VERSION

  mac_pods
  common_pods
end

target 'FSNotes iOS' do
    platform :ios, IOS_TARGET_VERSION

    common_pods
    ios_pods
end

target 'FSNotes iOS Share Extension' do
    platform :ios, IOS_TARGET_VERSION

    pod 'Highlightr', :git => 'https://github.com/glushchenko/Highlightr.git', :branch => 'master'
    pod 'NightNight', :git => 'https://github.com/glushchenko/NightNight.git', :branch => 'master'
    pod 'RNCryptor', '~> 5.1.0'
    pod 'SSZipArchive', :git => 'https://github.com/glushchenko/ZipArchive.git', :branch => 'master'
    pod 'Kanna', '~> 5.0.0'
end

post_install do |installer|
  installer.generated_projects.each do |project|
            project.targets.each do |target|
                target.build_configurations.each do |config|
                    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
                 end
            end
  end
  installer.pods_project.targets.each do |target|
    if target.name == 'cmark-gfm-swift-macOS'
      source_files = target.source_build_phase.files
      dummy = source_files.find do |file|
        file.file_ref.name == 'scanners.re'
      end
      source_files.delete dummy

      dummyM = source_files.find do |file|
        file.file_ref.name == 'module.modulemap'
      end
      source_files.delete dummyM
      puts "Deleting source file #{dummy.inspect} from target #{target.inspect}."
    end
  end
end
