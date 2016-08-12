module Amimono
  # This class will patch your project's copy resources script to match the one that would be
  # generated as if the `use_frameworks!` flag wouldn't be there
  class Patcher
    def self.patch_copy_resources_script(installer:)!
      project = installer.sandbox.project
      aggregated_targets = installer.aggregate_targets.reject { |target| target.label.include? 'Test' }
      aggregated_targets.each do |aggregated_target|
        path = aggregated_target.copy_resources_script_path
        resources = resources_by_config(aggregated_target: aggregated_target, project: project)
        generator = Pod::Generator::CopyResourcesScript.new(resources, aggregated_target.platform)
        generator.save_as(path)
        puts "[Amimono] Copy resources script patched for target #{aggregated_target.label}"
      end
    end

    private

    # Copied over from https://github.com/CocoaPods/CocoaPods/blob/master/lib/cocoapods/installer/xcode/pods_project_generator/aggregate_target_installer.rb#L115-L131
    # with some modifications to this particular use case
    def self.resources_by_config(aggregated_target:, project:)
      library_targets = aggregated_target.pod_targets.reject do |pod_target|
        # This reject doesn't matter much anymore. We have to process all targets because
        # every single one requires frameworks and this workaround doesn't work with Pods
        # that contains binaries
        !pod_target.should_build?
      end
      aggregated_target.user_build_configurations.keys.each_with_object({}) do |config, resources_by_config|
        resources_by_config[config] = library_targets.flat_map do |library_target|
          next [] unless library_target.include_in_build_config?(aggregated_target.target_definition, config)
          resource_paths = library_target.file_accessors.flat_map do |accessor|
            accessor.resources.flat_map { |res| res.relative_path_from(project.path.dirname) }
          end
          resource_bundles = library_target.file_accessors.flat_map do |accessor|
            accessor.resource_bundles.keys.map { |name| "#{library_target.configuration_build_dir}/#{name.shellescape}.bundle" }
          end
          # The `bridge_support_file` has been removed from this part
          (resource_paths + resource_bundles).uniq
        end
      end
    end
  end
end
