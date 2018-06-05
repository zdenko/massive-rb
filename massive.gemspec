Gem::Specification.new do |s|
  s.name = 'massive'
  s.version = "0.0.1"
  s.platform = Gem::Platform::RUBY
  s.summary = "A PostgreSQL-centric Data Access too for Ruby"
  s.description = s.summary
  s.author = "Rob Conery"
  s.email = "rob@conery.io"
  s.homepage = "https://github.com/robconery/massiverb"
  s.license = 'BSD-3-Clause'
  s.required_ruby_version = ">= 1.9.2"
  s.files = %w(LICENSE) + Dir["{spec,lib}/**/*.{rb,RB}"]
  s.require_path = "lib"
  s.add_development_dependency "rspec", '~> 0'
  s.add_runtime_dependency 'pg', '~> 0'
end