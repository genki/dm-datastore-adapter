# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{dm-datastore-adapter}
  s.version = "0.0.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Genki Takiuchi"]
  s.date = %q{2009-04-13}
  s.description = %q{This is a DataMapper adapter to DataStore of Google App Engine.}
  s.email = %q{genki@s21g.com}
  s.extra_rdoc_files = ["README", "LICENSE", "TODO"]
  s.files = ["LICENSE", "README", "Rakefile", "TODO", "lib/appengine-api-1.0-sdk-1.2.0.jar", "lib/dm-datastore-adapter", "lib/dm-datastore-adapter/datastore-adapter.rb", "lib/dm-datastore-adapter/merbtasks.rb", "lib/dm-datastore-adapter.rb", "spec/dm-datastore-adapter_spec.rb", "spec/spec_helper.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://jmerbist.appspot.com/}
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{asakusarb}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{This is a DataMapper adapter to DataStore of Google App Engine.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<dm-core>, [">= 0.9.10"])
      s.add_runtime_dependency(%q<addressable>, [">= 2.0.0"])
    else
      s.add_dependency(%q<dm-core>, [">= 0.9.10"])
      s.add_dependency(%q<addressable>, [">= 2.0.0"])
    end
  else
    s.add_dependency(%q<dm-core>, [">= 0.9.10"])
    s.add_dependency(%q<addressable>, [">= 2.0.0"])
  end
end
