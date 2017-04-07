require 'cocoapods-amimono/command'
require 'cocoapods-amimono/build_phases_updater'

Pod::HooksManager.register('cocoapods-amimono', :post_install) do |installer_context|
  # We exclude all targets that contain `Test`, which might not work for some test targets
  # that doesn't include that word
  pods_targets = installer_context.umbrella_targets.reject { |target| target.cocoapods_target_label.include? 'Test' }
  updater = Amimono::BuildPhasesUpdater.new
  updater.update_build_phases(installer_context, pods_targets)
end
