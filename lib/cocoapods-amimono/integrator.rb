module Amimono
  class Integrator

    FILELIST_SCRIPT = <<-SCRIPT.strip_heredoc
          #!/usr/bin/ruby
          intermediates_directory = ENV['OBJROOT']
          configuration = ENV['CONFIGURATION']
          platform = ENV['EFFECTIVE_PLATFORM_NAME']
          archs = ENV['ARCHS']
          target_name = ENV['TARGET_NAME']

          archs.split(" ").each do |architecture|
            Dir.chdir("\#{intermediates_directory}/Pods.build") do
              filelist = ""
              %s.each do |dependency|
                Dir.glob("\#{configuration}\#{platform}/\#{dependency}.build/Objects-normal/\#{architecture}/*.o") do |object_file|
                  next if ["Pods-\#{target_name}-dummy", "Pods_\#{target_name}_vers"].any? { |dummy_object| object_file.include? dummy_object }
                  filelist += File.absolute_path(object_file) + "\\n"
                end
              end
              File.write("\#{configuration}\#{platform}-\#{architecture}.objects.filelist", filelist)
            end
          end
        SCRIPT

    AMIMONO_FILELIST_BUILD_PHASE = '[Amimono] Create filelist per architecture'

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
      application_target = user_project.targets.find { |target| target.product_type.end_with? 'application' }
      # Remove the `Embed Pods Frameworks` build phase
      remove_embed_pods_frameworks(application_target: application_target)
      # Create or update [Amimono] build phase
      amimono_filelist_build_phase = create_or_get_amimono_phase(application_target: application_target, phase_name: AMIMONO_FILELIST_BUILD_PHASE, script: generate_filelist_script(aggregated_target: aggregated_target))
      application_target.build_phases.insert(1, amimono_filelist_build_phase)
      application_target.build_phases.uniq!
      user_project.save
    end

    private

    def remove_embed_pods_frameworks(application_target:)
      embed_pods_frameworks_build_phase = application_target.build_phases.find { |build_phase| build_phase.display_name.include? 'Embed Pods Frameworks' }
      return if embed_pods_frameworks_build_phase.nil?
      embed_pods_frameworks_build_phase.remove_from_project
    end

    def create_or_get_amimono_phase(application_target:, phase_name:, script:)
      return application_target.build_phases.find { |build_phase| build_phase.display_name.include? phase_name } || application_target.new_shell_script_build_phase(phase_name).tap do |shell_build_phase|
        shell_build_phase.shell_path = '/usr/bin/ruby'
        shell_build_phase.shell_script = script
      end
    end

    def generate_filelist_script(aggregated_target:)
      dependencies = aggregated_target.specs.map(&:name).reject { |dependency| dependency.include? '/'}
      puts "[Amimono] #{dependencies.count} dependencies found"
      FILELIST_SCRIPT % dependencies.to_s
    end
  end
end
