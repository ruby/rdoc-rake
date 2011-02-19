# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.add_include_dirs '../rdoc'
Hoe.plugin :git

Hoe.spec 'rdoc-rake' do
  developer 'Eric Hodel', 'drbrain@segment7.net'

  extra_deps       << ['rdoc', '~> 3.0']
  extra_rdoc_files << 'Rakefile'

  self.rdoc_locations =
    'docs.seattlerb.org:/data/www/docs.seattlerb.org/rdoc-rake'
end

# vim: syntax=Ruby
