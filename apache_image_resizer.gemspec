# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "apache_image_resizer"
  s.version = "0.0.6"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Jens Wille"]
  s.date = "2012-04-02"
  s.description = "Apache module providing image resizing functionality."
  s.email = "jens.wille@uni-koeln.de"
  s.extra_rdoc_files = ["README", "COPYING", "ChangeLog"]
  s.files = ["lib/apache/image_resizer.rb", "lib/apache/mock_constants.rb", "lib/apache/image_resizer/util.rb", "lib/apache/image_resizer/version.rb", "ChangeLog", "COPYING", "README", "Rakefile", "spec/apache/image_resizer_spec.rb", "spec/apache/image_resizer/util_spec.rb", "spec/spec_helper.rb", ".rspec"]
  s.homepage = "http://github.com/blackwinter/apache_image_resizer"
  s.rdoc_options = ["--line-numbers", "--main", "README", "--charset", "UTF-8", "--title", "apache_image_resizer Application documentation (v0.0.6)", "--all"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.21"
  s.summary = "Apache module providing image resizing functionality."

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rmagick>, [">= 0"])
      s.add_runtime_dependency(%q<ruby-filemagic>, [">= 0"])
      s.add_runtime_dependency(%q<ruby-nuggets>, [">= 0"])
      s.add_runtime_dependency(%q<apache_secure_download>, [">= 0"])
    else
      s.add_dependency(%q<rmagick>, [">= 0"])
      s.add_dependency(%q<ruby-filemagic>, [">= 0"])
      s.add_dependency(%q<ruby-nuggets>, [">= 0"])
      s.add_dependency(%q<apache_secure_download>, [">= 0"])
    end
  else
    s.add_dependency(%q<rmagick>, [">= 0"])
    s.add_dependency(%q<ruby-filemagic>, [">= 0"])
    s.add_dependency(%q<ruby-nuggets>, [">= 0"])
    s.add_dependency(%q<apache_secure_download>, [">= 0"])
  end
end
