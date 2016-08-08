module Amimono
  class Integrator

    FILELIST_SCRIPT = <<-SCRIPT.strip_heredoc
          declare -a EXCLUDE=("Pods-${TARGET_NAME}-dummy" "Pods_${TARGET_NAME}_vers");
          IFS=" " read -r -a SPLIT <<< "$ARCHS"
          for ARCH in "${SPLIT[@]}"; do
            cd "$OBJROOT/Pods.build"
            filelist=""
            for dependency in "${DEPENDENCIES[@]}"; do
              path="${CONFIGURATION}${EFFECTIVE_PLATFORM_NAME}/${dependency}.build/Objects-normal/${ARCH}/*.o"
              for obj_file in $path; do
                should_continue=false
                for exclude_element in "${EXCLUDE[@]}"; do
                  if [[ $obj_file == *"${exclude_element}"* ]]
                  then
                    should_continue = true
                  fi
                done
                if [ "$should_continue" = true ]; then
                  continue
                fi
                filelist+="${OBJROOT}/Pods.build/${obj_file}"
                filelist+=$'\\n'
              done
            done
            filelist=${filelist\%$'\\n'}
            echo "$filelist" > "${CONFIGURATION}${EFFECTIVE_PLATFORM_NAME}-${ARCH}.objects.filelist"
          done
        SCRIPT

    AMIMONO_FILELIST_BUILD_PHASE = '[Amimono] Create filelist per architecture'

    def update_xcconfigs(aggregated_target_sandbox_path:)
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

    def update_build_phases(aggregated_target:)
      user_project = aggregated_target.user_project
      application_target = user_project.targets.find { |target| target.product_type.end_with? 'application' }
      # Remove the `Embed Pods Frameworks` build phase
      remove_embed_pods_frameworks(application_target: application_target)
      # Create or update [Amimono] build phase
      create_or_update_amimono_phase(application_target: application_target, phase_name: AMIMONO_FILELIST_BUILD_PHASE, script: generate_filelist_script(aggregated_target: aggregated_target))
      user_project.save
    end

    private

    def remove_embed_pods_frameworks(application_target:)
      embed_pods_frameworks_build_phase = application_target.build_phases.find { |build_phase| build_phase.display_name.include? 'Embed Pods Frameworks' }
      return if embed_pods_frameworks_build_phase.nil?
      embed_pods_frameworks_build_phase.remove_from_project
    end

    def create_or_update_amimono_phase(application_target:, phase_name:, script:)
      amimono_filelist_build_phase = application_target.build_phases.find { |build_phase| build_phase.display_name.include? phase_name } || application_target.new_shell_script_build_phase(phase_name)
      amimono_filelist_build_phase.shell_path = '/bin/bash'
      amimono_filelist_build_phase.shell_script = script
      application_target.build_phases.insert(1, amimono_filelist_build_phase)
      application_target.build_phases.uniq!
    end

    def generate_filelist_script(aggregated_target:)
      dependencies = aggregated_target.specs.map(&:name).reject { |dependency| dependency.include? '/'}
      puts "[Amimono] #{dependencies.count} dependencies found"
      bash_array = dependencies.map { |dependency| "'#{dependency}'" }.join ' '
      declare_statement = "declare -a DEPENDENCIES=(%s);\n" % bash_array
      declare_statement + FILELIST_SCRIPT
    end
  end
end
