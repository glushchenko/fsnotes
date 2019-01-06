use_frameworks!

MAC_TARGET_VERSION = '10.11'
IOS_TARGET_VERSION = '10'

def mac_pods
    pod 'MASShortcut', '~> 2.0'
end

def ios_pods
    pod 'Solar', '~> 2.0'
    pod 'NightNight', '~> 0.5.0'
    pod 'DKImagePickerController', '3.8.1'
    pod 'GSImageViewerController'
    pod 'SSZipArchive'
end

def common_pods
    pod 'Highlightr', '~> 2.0'
    pod 'Down', '~> 0.6.0'
    pod 'cmark-gfm-swift', :git => 'https://github.com/glushchenko/cmark-gfm-swift.git', :branch => 'master'
end

def framework_pods
    pod 'SwiftLint', '~> 0.26.0'
end

target 'FSNotesCore iOS' do
    platform :ios, IOS_TARGET_VERSION
    pod 'NightNight', '~> 0.5.0'
    framework_pods
end

target 'FSNotesCore macOS' do
    platform :osx, MAC_TARGET_VERSION
    pod 'MASShortcut', '~> 2.0'
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

target 'FSNotes iOS' do
    platform :ios, IOS_TARGET_VERSION

    common_pods
    ios_pods
end

target 'FSNotes iOS Share Extension' do
    platform :ios, IOS_TARGET_VERSION

    pod 'Highlightr', '~> 2.0'
    pod 'NightNight', '~> 0.5.0'
end
