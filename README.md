# cocoapods-amimono

<p align="center">
  <img src="https://dl.dropboxusercontent.com/u/12352209/GitHub/amimono.gif" alt="amimono"/>
</p>

Move all dynamic frameworks symbols into the main executable.

## Why would you want this plugin in your Podfile?

Apple introduced dynamic linking on iOS 8 alongside with Swift. Shortly after, this was adopted by CocoaPods as a requirement to use Pods that contain Swift, because Xcode can't use static libraries with Swift.

On iOS 9.1, a dyld crash affected the vast majority of apps that used a high number of dynamic frameworks. You can learn more about the issue on [artsy/eigen#1246](https://github.com/artsy/eigen/issues/1246). Although the issue was fixed on iOS 9.3.2, it was clear that having a high number of dynamic frameworks was not a good idea. During WWDC 2016, someone asked what would be the optimal number of dynamic frameworks on an iOS application and we got the following response:

> Apple advises to use about half a dozen dynamic frameworks in an app. Hard to achieve with external & internal deps.
> -- from [Twitter](https://twitter.com/arekholko/status/743135179514978304)

This is hardly an option for some. If you think you might be in that group, then continue reading.

## What is this plugin doing?

This plugin is based on [dyld-image-loading-performance](https://github.com/stepanhruda/dyld-image-loading-performance). In a nutshell, it copies all symbols of your CocoaPods dependencies into your main app executable, so the dynamic linker doesn't have to load the frameworks. You can verify this yourself by enabling

![log_setting_xcode.png](https://dl.dropboxusercontent.com/u/12352209/GitHub/log_setting_xcode.png)

and looking at the log output you shouldn't find any `dlopen` call of your CocoaPods frameworks.

## Limitations

Currently this plugin has the following limitations:

* You will have modify your `post_install` hook. This is necessary because the CocoaPods plugin API currently doesn't offer everything that the gem needs.
* Only dependencies compiled from source will work. This means dependencies with bundled binaries (like vendored static frameworks) won't work. You will have to add these manually to your Xcode project.

## Installation

```bash
gem install cocoapods-amimono
````

## Usage

Add the following to your Podfile:

```ruby
plugin 'cocoapods-amimono'
```

Add the following to your `post_install` hook:

```ruby
post_install do |installer|
  require 'cocoapods-amimono/patcher'
  Amimono::Patcher.patch_copy_resources_script(installer: installer)
  ...
```
