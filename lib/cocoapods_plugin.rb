require 'cocoapods-amimono/command'
require 'cocoapods-amimono/integrator'

Pod::HooksManager.register('cocoapods-amimono', :post_install) do |installer_context|
  # Find the aggregated target
  # This is probably wrong, all agregated targets are prefixed by 'Pods-'
  # but this works for now because find will return the first one
  # which is usually the app target
  pods_target = installer_context.umbrella_targets.find do |target|
    target.cocoapods_target_label.include? 'Pods'
  end
  puts "[Amimono] Pods target found: #{pods_target.cocoapods_target_label}"

  path = installer_context.sandbox.target_support_files_dir pods_target.cocoapods_target_label

  integrator = Amimono::Integrator.new
  integrator.update_xcconfigs(aggregated_target_sandbox_path: path)
  puts "[Amimono] xcconfigs updated with filelist"
  integrator.update_build_phases(aggregated_target: pods_target)
  puts "[Amimono] Build phases updated"
end
