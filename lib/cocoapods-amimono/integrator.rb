module Amimono
  class Integrator

    attr_reader :installer_context

    def initialize(installer_context)
      @installer_context = installer_context
    end

    FILELIST_SCRIPT = <<-SCRIPT.strip_heredoc
          IFS=" " read -r -a SPLIT <<< "$ARCHS"
          for ARCH in "${SPLIT[@]}"; do
            cd "$OBJROOT/Pods.build"
            filelist=""
            for dependency in "${DEPENDENCIES[@]}"; do
              path="${CONFIGURATION}${EFFECTIVE_PLATFORM_NAME}/${dependency}.build/Objects-normal/${ARCH}"
              if [ -d "$path" ]; then
                search_path="$path/*.o"
                for obj_file in $search_path; do
                  filelist+="${OBJROOT}/Pods.build/${obj_file}"
                  filelist+=$'\\n'
                done
              fi
            done
            filelist=${filelist\%$'\\n'}
            echo "$filelist" > "${CONFIGURATION}${EFFECTIVE_PLATFORM_NAME}-${ARCH}.objects.filelist"
          done
        SCRIPT

    AMIMONO_FILELIST_BUILD_PHASE = '[Amimono] Create filelist per architecture'

    def update_xcconfigs(aggregated_target_sandbox_path)
      path = aggregated_target_sandbox_path
      archs = ['armv7', 'armv7s', 'arm64', 'i386', 'x86_64']
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

    def update_build_phases(aggregated_targets)
      # All user projects should be the same I hope
      user_project = aggregated_targets.first.user_project
      aggregated_targets.each do |aggregated_target|
        # This pick is probably wrong, but works for most of the simple cases
        user_target = aggregated_target.user_targets.first
        # Remove the `Embed Pods Frameworks` build phase
        remove_embed_pods_frameworks(user_target)
        # Create or update [Amimono] build phase
        create_or_update_amimono_phase(user_target, AMIMONO_FILELIST_BUILD_PHASE, generate_filelist_script(aggregated_target))
        puts "[Amimono] Build phases updated for target #{aggregated_target.cocoapods_target_label}"
      end
      user_project.save
    end

    private

    def remove_embed_pods_frameworks(user_target)
      embed_pods_frameworks_build_phase = user_target.build_phases.find { |build_phase| build_phase.display_name.include? 'Embed Pods Frameworks' }
      return if embed_pods_frameworks_build_phase.nil?
      embed_pods_frameworks_build_phase.remove_from_project
    end

    def create_or_update_amimono_phase(user_target, phase_name, script)
      amimono_filelist_build_phase = user_target.build_phases.find { |build_phase| build_phase.display_name.include? phase_name } || user_target.new_shell_script_build_phase(phase_name)
      amimono_filelist_build_phase.shell_path = '/bin/bash'
      amimono_filelist_build_phase.shell_script = script
      user_target.build_phases.insert(1, amimono_filelist_build_phase)
      user_target.build_phases.uniq!
    end

    def generate_filelist_script(aggregated_target)
      dependencies = []
      installer_context.pods_project.targets.select { |target| target.name == aggregated_target.cocoapods_target_label }.first.dependencies.each do |dependency|
        case dependency.target.product_type
        when 'com.apple.product-type.framework'
          dependencies << "'#{dependency.name}'"
        when 'com.apple.product-type.bundle'
          # ignore
        end
      end
      puts "[Amimono] #{dependencies.count} dependencies found"
      "declare -a DEPENDENCIES=(#{dependencies.join(' ')});\n" + FILELIST_SCRIPT
    end
  end
end
