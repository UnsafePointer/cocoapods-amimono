require 'cocoapods-amimono/command'
require 'cocoapods-amimono/integrator'

Pod::HooksManager.register('cocoapods-amimono', :post_install) do |installer_context|
  # Find the aggregated target
  pods_target = installer_context.umbrella_targets.find do |target|
    target.cocoapods_target_label.include? 'Pods'
  end
  puts "[Amimono] Pods target found: #{pods_target.cocoapods_target_label}"

  path = installer_context.sandbox.target_support_files_dir pods_target.cocoapods_target_label

  integrator = Amimono::Integrator.new
  integrator.update_xcconfigs(aggregated_target_sandbox_path: path)
  integrator.update_build_phases(aggregated_target: pods_target)
end
