# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cocoapods-amimono/gem_version.rb'

Gem::Specification.new do |spec|
  spec.name          = 'cocoapods-amimono'
  spec.version       = CocoapodsAmimono::VERSION
  spec.authors       = ['Renzo Crisóstomo']
  spec.email         = ['renzo.crisostomo@xing.com']
  spec.description   = %q{A short description of cocoapods-amimono.}
  spec.summary       = %q{A longer description of cocoapods-amimono.}
  spec.homepage      = 'https://github.com/EXAMPLE/cocoapods-amimono'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
end
