module Amimono
  class XCConfigUpdater
    attr_reader :installer

    def initialize(installer)
      @installer = installer
    end

    def update_xcconfigs(aggregated_target, aggregated_target_sandbox_path)
      path = aggregated_target_sandbox_path
      archs = ['armv7', 'armv7s', 'arm64', 'i386', 'x86_64']
      # Find all xcconfigs for the aggregated target
      Dir.entries(path).select { |entry| entry.end_with? 'xcconfig' }.each do |entry|
        full_path = path + entry
        xcconfig = Xcodeproj::Config.new full_path
        # Clear the -frameworks flag
        xcconfig.other_linker_flags[:frameworks] = Set.new(aggregated_target.pod_targets.reject(&:should_build?).map(&:name))
        # Add -filelist flag instead, for each architecture
        archs.each do |arch|
          config_key = "OTHER_LDFLAGS[arch=#{arch}]"
          xcconfig.attributes[config_key] = "$(inherited) -filelist \"$(OBJROOT)/Pods.build/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)-$(TARGET_NAME)-#{arch}.objects.filelist\""
        end
        xcconfig.save_as full_path
      end
    end

  end
end
