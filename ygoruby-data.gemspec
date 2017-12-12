# coding: utf-8

Gem::Specification.new do |spec|
  spec.name = 'ygoruby-data'
  spec.version = 0.1
  spec.authors = ['IamI']
  spec.email = ['xinguangyao@gmail.com']

  spec.summary = %q{Basic classes for using ygopro.}
  spec.description = %q{Basic needed classes when use ygopro.}
  spec.homepage = 'http://ii.mist.so'
  spec.license = 'MIT'

  spec.files = Dir['lib/*.*']

  spec.add_dependency 'sqlite3', '~> 1.3', '>= 1.3.13'
  spec.add_dependency 'ruby-lzma', '~> 0.4', '>= 0.4.3'
end
