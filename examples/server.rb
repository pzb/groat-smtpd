# vim: set sw=2 sts=2 ts=2 et syntax=ruby: #
=begin license
  Copyright 2011 Novell, Inc.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  Author(s):
    Peter Bowen <pzbowen@gmail.com> Ottawa, Ontario, Canada
=end

require 'rubygems'
require 'groat/smtpd/smtp'
require 'groat/smtpd/server'
require 'groat/smtpd/extensions/pipelining'
require 'groat/smtpd/extensions/eightbitmime'
require 'groat/smtpd/extensions/help'


class SMTPConnection < Groat::SMTPD::SMTP
  include Groat::SMTPD::Extensions::Pipelining
  include Groat::SMTPD::Extensions::EightBitMIME
  include Groat::SMTPD::Extensions::Help

  def deliver!
    puts "Envelope Sender: #{@mailfrom}"
    puts "Envelope Recipients: #{@rcptto.join(" ")}"
    puts "Message follows"
    puts @message
    ["In testing mode", "Message delivered to stdout"]
  end

  def send_greeting
    reply :code => 220, :message => "Welcome to the Groat example server"
  end

  def initialize
    @hostname = 'smtp.example.com'
    super
  end
end

s = Groat::SMTPD::Server.new SMTPConnection, 10025
s.start
s.join
