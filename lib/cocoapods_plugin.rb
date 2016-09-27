require 'cocoapods-amimono/command'
require 'cocoapods-amimono/integrator'

Pod::HooksManager.register('cocoapods-amimono', :post_install) do |installer_context|
  # We exclude all targets that contain `Test`, which might not work for some test targets
  # that doesn't include that word
  pods_targets = installer_context.umbrella_targets.reject { |target| target.cocoapods_target_label.include? 'Test' }
  target_info = Hash.new
  pods_targets.each do |pods_target|
    puts "[Amimono] Pods target found: #{pods_target.cocoapods_target_label}"
    target_info[pods_target] = installer_context.sandbox.target_support_files_dir pods_target.cocoapods_target_label
  end

  integrator = Amimono::Integrator.new(installer_context)
  target_info.each do |pods_target, path|
    integrator.update_xcconfigs(path)
    puts "[Amimono] xcconfigs updated with filelist for target #{pods_target.cocoapods_target_label}"
  end
  integrator.update_build_phases(target_info.keys)
end
