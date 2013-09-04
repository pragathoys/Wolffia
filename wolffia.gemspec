$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "wolffia"
  s.version     = "0.0.1"
  s.platform    = "ruby"
  s.authors     = ["John Marountas"]
  s.email       = ["unclearbit@gmail.com"]
  s.homepage    = "http://www.programmer.gr"
  s.summary     = "A tiny RoR CMS."
  s.description = "With this gem you can install on your RoR app an expandable Rails CMS."
  s.files       = Dir.glob("{lib}/**/*") + Dir.glob("{lib}/**/templates/*") 
  s.require_path = 'lib'
  s.add_dependency "rails", "~> 3.2.13"
end