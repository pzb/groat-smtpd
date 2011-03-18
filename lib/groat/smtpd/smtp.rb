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

require 'groat/smtpd/smtpsyntax'

module Groat
module SMTPD
  class SMTP < SMTPSyntax
    ehlo_keyword "x-groat"
    verb :mail, :smtp_verb_mail
    verb :rcpt, :smtp_verb_rcpt
    verb :data, :smtp_verb_data
    verb :helo, :smtp_verb_helo
    verb :ehlo, :smtp_verb_ehlo
    verb :quit, :smtp_verb_quit
    verb :rset, :smtp_verb_rset
    verb :noop, :smtp_verb_noop

    def initialize(*args)
      @hostname = "groat.example" if @hostname.nil?
      super(*args)
    end

    def deliver!
    end

    # Reply methods

    def response_ok(args = {})
      defaults = {:code => 250, :message => "OK"}
      reply defaults.merge(args)
    end

    def response_bad_command(args = {})
      defaults = {:code => 500, :message => "Bad command"}
      reply defaults.merge(args)
    end

    def response_syntax_error(args = {})
      defaults = {:code => 501, :message => "Syntax error"}
      reply defaults.merge(args)
    end

    def response_bad_sequence(args = {})
      defaults = {:code => 503, :message => "Bad sequence of commands", 
                  :terminate => true }
      reply defaults.merge(args)
    end

    def response_bad_command_parameter(args = {})
      defaults = {:code => 504, :message => "Invalid parameter"}
      reply defaults.merge(args)
    end

    def response_no_valid_rcpt(args = {})
      defaults = {:code => 554, :message => "No valid recipients"}
      reply defaults.merge(args)
    end

    def response_bad_parameter(args = {})
      defaults = {:code => 555, :message => "Parameter not recognized"}
      reply defaults.merge(args)
    end

    def response_service_shutdown(args = {})
      defaults = {:code => 421, :message => "Server closing connection", 
            :terminate => true}
      reply defaults.merge(args)
    end

    # Groat framework methods

    def send_greeting
      reply :code => 220, :message => "#{@hostname} ESMTP Ready"
    end

    def service_shutdown
      response_service_shutdown
    end

    def verb_missing(verb, parameters)
      response_bad_command :message => "Unknown command #{verb}"
    end

    # Utility functions

    # No pipelining allowed (not in RFC5321)
    def check_command_group
      if clientdata?
        response_bad_sequence
      end
    end

    def reset_connection
      @hello = nil 
      @hello_extra = nil
      @esmtp = false
      reset_buffers
      super
    end

    def reset_buffers
      @mailfrom = nil
      @rcptto = []
      @message = ""
    end

    def in_mail_transaction?
      not @mailfrom.nil?
    end

    def esmtp?
      @esmtp
    end

    # Generic handler for hello action
    # Keyword determines Mail Service Type
    # See: http://www.iana.org/assignments/mail-parameters
    def handle_hello(args, keyword)
      keyword = keyword.to_s.upcase.intern
      check_command_group
      response_syntax_error if args.empty?
      hello, hello_extra = args.split(" ", 2)
      hello =~ DOMAIN_OR_LITERAL
      if $~.nil?
        respond_syntax_error :message=>"Syntax Error: expected hostname or IP literal"
      elsif hello.start_with? '[' and not valid_address_literal(hello)
        respond_syntax_error :message=>"Syntax Error: invalid IP literal"
      else
        @hello = hello
        @hello_extra = hello_extra
      end
      reset_buffers
      response_text = ["#{@hostname} at your service"]
      if (keyword == :EHLO)
        @esmtp = true
        ehlo_keywords.each do |kw, params|
          param_str = params.to_a.join(' ')
          if param_str.empty?
            response_text << "#{kw}"
          else
            response_text << "#{kw} #{param_str}"
          end
        end
      end
      reply :code => 250, :message => response_text
    end

    # Verb handlers
    def smtp_verb_helo(args)
      handle_hello(args, :HELO)
    end

    def smtp_verb_ehlo(args)
      handle_hello(args, :EHLO)
    end

    define_hook :validate_mailfrom
    def smtp_verb_mail(args)
      check_command_group
      response_bad_sequence if @hello.nil?
      # This should be start_with? 'FROM:<', but Outlook puts a space
      # between the ':' and the '<'
      response_syntax_error unless args.upcase.start_with? 'FROM:'
      # Remove leading "FROM:" and following spaces
      args = args[5..-1].lstrip
      if args[0..2].rstrip.eql? '<>'
        path = '<>'
        param_str = args[3..-1].to_s
      else
        path, param_str = split_path(args)
        response_syntax_error :message => 'Path error' if path.nil?
      end
      unless param_str.strip.empty?
        response_syntax_error unless esmtp?
      end
      params = parse_params(param_str)
      response_bad_parameter unless mail_params_valid(params)
      # Validation complete
      # RFC5321 § 4.1.1.2
      # "This command clears the reverse-path buffer, the forward-path 
      #  buffer, and the mail data buffer, and it inserts the reverse-path 
      #  information from its argument clause into the reverse-path buffer."
      reset_buffers
      process_mail_params(params)
      mailfrom = normalize_path(path)
      run_hook :validate_mailfrom, mailfrom
      @mailfrom = mailfrom
      response_ok
    end

    define_hook :validate_rcptto
    def smtp_verb_rcpt(args)
      check_command_group
      response_bad_sequence if @mailfrom.nil?
      # This should be start_with? 'TO:<', but Outlook puts a space
      # between the ':' and the '<'
      response_syntax_error unless args.upcase.start_with? 'TO:'
      # Remove leading "TO:" and the following spaces
      args = args[3..-1].lstrip
      path, param_str = split_path(args)
      response_syntax error :message => 'Path error' if path.nil?
      unless param_str.strip.empty?
        response_syntax_error unless esmtp?
      end
      params = parse_params(param_str)
      rcptto = normalize_path(path)
      run_hook :validate_rcptto, rcptto
      @rcptto << rcptto
      response_ok
    end

    def smtp_verb_data(args)
      check_command_group
      response_syntax_error unless args.empty?
      return response_no_valid_rcpt if @rcptto.count < 1
      toclient "354 Enter message, ending with \".\" on a line by itself.\r\n"
      loop do
        line = fromclient
        # RFC 5321 § 4.1.1.4 
        # "The custom of accepting lines ending only in <LF>, as a concession to
        #  non-conforming behavior on the part of some UNIX systems, has proven
        #  to cause more interoperability problems than it solves, and SMTP
        #   server systems MUST NOT do this, even in the name of improved
        #   robustness."
        break if line.chomp("\r\n").eql?('.')
        # RFC5321 sect 4.5.2, remove leading '.' if found
        line.slice!(0) if line.start_with? '.'
        @message << line
      end
      message = deliver!
      reset_buffers
      response_ok :message => message
    end

    def smtp_verb_rset(args)
      check_command_group
      response_syntax_error unless args.empty?
      reset_buffers
      response_ok
    end

    def smtp_verb_quit(args)
      check_command_group
      response_syntax_error unless args.empty?
      reset_buffers
      reply :code=>221, 
            :message=>"#{@hostname} Service closing transmission channel", 
            :terminate=>true
    end

    # RFC 5321 § 4.1.1.9
    # "If a parameter string is specified, servers SHOULD ignore it."
    def smtp_verb_noop(args)
      check_command_group
      response_ok
    end
  end
end
end
