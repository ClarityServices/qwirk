Gem::Specification.new do |s|
  s.name        = "modern_times"
  s.summary     = 'Asynchronous task library'
  s.description = 'Generic asynchronous task library'
  s.platform    = 'java'
  s.authors     = ['Brad Pardee']
  s.email       = ['bradpardee@gmail.com']
  s.homepage    = 'http://github.com/ClarityServices/modern_times'
  s.files       = Dir["{app,examples,lib,config}/**/*"] + %w(LICENSE.txt Rakefile Gemfile History.md README.md)
  s.version     = '0.4.0.alpha1'
  s.add_dependency 'jruby-jms', ['>= 0.11.2']
  s.add_dependency 'gene_pool'
  s.add_dependency 'rumx'
  s.add_dependency 'rack'
end
