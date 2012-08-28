# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "exception_notification"
  s.version = "2.3.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Jamis Buck", "Josh Peek", "Tim Connor"]
  s.date = "2010-03-13"
  s.email = "timocratic@gmail.com"
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.11"
  s.summary = "Exception notification by email for Rails apps - 2.3-stable compatible version"

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
