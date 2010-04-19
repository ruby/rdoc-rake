# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.add_include_dirs '../trunk/lib'
Hoe.plugin :git

Hoe.spec 'rdoc-rake' do
  self.rubyforge_name = 'rdoc'
  developer 'Eric Hodel', 'drbrain@segment7.net'

  extra_deps       << ['rdoc', '~> 2.5']
  extra_rdoc_files << 'Rakefile'
end

# vim: syntax=Ruby
