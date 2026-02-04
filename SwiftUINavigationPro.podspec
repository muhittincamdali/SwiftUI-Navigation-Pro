Pod::Spec.new do |s|
  s.name             = 'SwiftUINavigationPro'
  s.version          = '1.0.0'
  s.summary          = 'Advanced navigation framework for SwiftUI with deep linking and routing.'
  s.description      = 'SwiftUINavigationPro provides advanced navigation for SwiftUI with deep linking, routing, and coordinator patterns.'
  s.homepage         = 'https://github.com/muhittincamdali/SwiftUI-Navigation-Pro'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Muhittin Camdali' => 'contact@muhittincamdali.com' }
  s.source           = { :git => 'https://github.com/muhittincamdali/SwiftUI-Navigation-Pro.git', :tag => s.version.to_s }
  s.ios.deployment_target = '15.0'
  s.swift_versions = ['5.9', '5.10', '6.0']
  s.source_files = 'Sources/**/*.swift'
  s.frameworks = 'Foundation', 'SwiftUI'
end
