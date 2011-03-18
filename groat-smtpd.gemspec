# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "groat/smtpd/version"

Gem::Specification.new do |s|
  s.name        = "groat-smtpd"
  s.version     = Groat::SMTPD::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Peter Bowen"]
  s.email       = ["pzbowen@gmail.com"]
  s.license     = "Apache 2.0"
  s.homepage    = "http://github.com/pzb/groat-smtpd"
  s.summary     = %q{Groat SMTPD is a library for writing Internet mail servers}
  s.description = <<-EOF
Groat SMTPD is a flexible extensible RFC-compliant implementation of the
Simple Mail Transfer Protocol.  It includes support for the 8bit-MIMEtransport,
Authentication, BINARYMIME, CHUNKING, Pipelining, Message Size Declaraion, and
STARTTLS service extensions.  It also includes framework for the non-standard
ONEX and VERB verbs and the SASL LOGIN mechanism.
EOF

  s.rubyforge_project = "groat-smtpd"

  s.add_dependency 'hooks', '>= 0.1.3'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
