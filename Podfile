use_frameworks!

def available_pods
    platform :osx, '10.11'
    pod 'MASShortcut'
    pod 'Down', '~> 0.4.2'
    pod 'Highlightr', :git => 'https://github.com/glushchenko/Highlightr.git', :branch => 'swift4-osx'
end

target 'FSNotes' do
    available_pods
end

target 'FSNotes (iCloud Documents)' do
    available_pods
end

target 'FSNotes iOS' do
    platform :ios, '10'
    pod 'Highlightr', :git => 'https://github.com/glushchenko/Highlightr.git', :branch => 'swift4-osx'
    pod 'Solar'
end
