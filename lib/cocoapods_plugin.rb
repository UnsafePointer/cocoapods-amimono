require 'cocoapods-amimono/command'
require 'cocoapods-amimono/build_phases_updater'

Pod::HooksManager.register('cocoapods-amimono', :post_install) do |installer_context|
  pods_targets = installer_context.umbrella_targets
  updater = Amimono::BuildPhasesUpdater.new
  updater.update_build_phases(installer_context, pods_targets)
end
