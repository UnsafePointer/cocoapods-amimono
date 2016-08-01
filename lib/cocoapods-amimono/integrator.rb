module Amimono
  class Integrator

    def update_xcconfigs(aggregated_target_sandbox_path:)
      path = aggregated_target_sandbox_path
      archs = ['armv7', 'arm64', 'i386', 'x86_64']
      # Find all xcconfigs for the aggregated target
      Dir.entries(path).select { |entry| entry.end_with? 'xcconfig' }.each do |entry|
        full_path = path + entry
        xcconfig = Xcodeproj::Config.new full_path
        # Clear the -frameworks flag
        xcconfig.other_linker_flags[:frameworks] = Set.new
        # Add -filelist flag instead, for each architecture
        archs.each do |arch|
          config_key = "OTHER_LDFLAGS[arch=#{arch}]"
          xcconfig.attributes[config_key] = "$(inherited) -filelist \"$(OBJROOT)/Pods.build/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)-#{arch}.objects.filelist\""
        end
        xcconfig.save_as full_path
      end
    end

    def update_build_phases(aggregated_target:)
      user_project = aggregated_target.user_project
      # Remove the `Embed Pods Frameworks` build phase
      application_target = user_project.targets.find { |target| target.product_type.end_with? 'application' }
      embed_pods_frameworks_build_phase = application_target.build_phases.find { |build_phase| build_phase.display_name.include? 'Embed Pods Frameworks' }
      embed_pods_frameworks_build_phase.remove_from_project
      # Check if [Amimono] phase already exist
      amimono_build_phase = application_target.build_phases.find { |build_phase| build_phase.display_name.include? '[Amimono]' }
      user_project.save
      return unless amimono_build_phase.nil?
      # Add new shell
      shell_build_phase = application_target.new_shell_script_build_phase '[Amimono] Create filelist per architecture'
      application_target.build_phases.insert(1, shell_build_phase)
      application_target.build_phases.uniq!
      shell_build_phase.shell_path = '/usr/bin/ruby'
      shell_build_phase.shell_script = <<-SCRIPT.strip_heredoc
        #!/usr/bin/ruby
        intermediates_directory = ENV['OBJROOT']
        configuration = ENV['CONFIGURATION']
        platform = ENV['EFFECTIVE_PLATFORM_NAME']
        archs = ENV['ARCHS']

        archs.split(" ").each do |architecture|
          Dir.chdir("\#{intermediates_directory}/Pods.build") do
            filelist = ""
            Dir.glob("\#{configuration}\#{platform}/*.build/Objects-normal/\#{architecture}/*.o") do |object_file|
              filelist += File.absolute_path(object_file) + "\\n"
            end
            File.write("\#{configuration}\#{platform}-\#{architecture}.objects.filelist", filelist)
          end
        end
      SCRIPT
      user_project.save
    end

  end
end
