use_frameworks!

MAC_TARGET_VERSION = '10.11'
IOS_TARGET_VERSION = '10'

def mac_pods
    pod 'MASShortcut', '~> 2.0'
end

def common_pods
    pod 'Highlightr', '~> 2.0'
    pod 'Down', '~> 0.5.2'
end

def framework_pods
    pod 'SwiftLint', '~> 0.26.0'
end

target 'FSNotesCore_iOS' do
    platform :ios, IOS_TARGET_VERSION
    framework_pods
end

target 'FSNotesCore_macOS' do
    platform :osx, MAC_TARGET_VERSION
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
    pod 'Solar', '~> 2.0'
    pod 'NightNight', '~> 0.5.0'
end
