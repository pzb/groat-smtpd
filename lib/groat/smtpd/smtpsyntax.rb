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

require 'groat/smtpd/base'
require 'ipaddr'

## SMTP Syntax implements the basic functions
## that allow implementing RFC 5321 and RFC 3848
## It does not define any verbs

module Groat
module SMTPD
  class SMTPExtensionError < Exception
  end

  class SMTPResponse < Response
    def initialize(args = {})
      @code = args[:code] || 500
      super(args)
    end

    def reply_text
      text = ""
      if @message.is_a? Array
        last = @message.pop
        if @message.count > 0
          @message.each do |line|
            text << @code.to_s + "-#{line}\r\n"
          end
        end
        text << @code.to_s + " #{last}\r\n"
      else
        text << @code.to_s + " #{@message}\r\n"
      end
    end
  end

  class SMTPSyntax < Base
    def initialize(*args)
      super(*args)
      @response_class = SMTPResponse
    end
    

    inheritable_attr(:ehlo_keywords)
    self.ehlo_keywords = {}
    inheritable_attr(:smtp_verbs)
    self.smtp_verbs = {}
    inheritable_attr(:mail_parameters)
    self.mail_parameters = {}
    inheritable_attr(:rcpt_parameters)
    self.rcpt_parameters = {}
    inheritable_attr(:mail_maxlen)
    self.mail_maxlen = 512
    inheritable_attr(:rcpt_maxlen)
    self.rcpt_maxlen = 512

    define_hook :before_all_verbs
    define_hook :after_all_verbs

    def self.ehlo_keyword(keyword, params = [], condition = nil)
      sym = keyword.to_s.upcase.intern
      ehlo_keywords[sym] = {:params => params, :condition => condition}
    end

    def self.ehlo_keyword_known?(kw)
      sym = kw.to_s.upcase.intern
      ehlo_keywords.has_key? sym
    end

    def ehlo_keywords
      list = {}
      self.class.ehlo_keywords.each do |k, v|
        valid = false

        if v[:condition].nil?
          valid = true
        else
          valid = send v[:condition]
        end

        if valid
          if v[:params].kind_of? Symbol
            params = send v[:params]
          else
            params = v[:params]
          end
          list[k] = list[k].to_a|params.to_a
        end
      end
      list
    end

    def self.run_verb_hook_for(hook, verb, scope, *args)
      if not smtp_verbs[verb].nil? and not smtp_verbs[verb][hook].nil?
        smtp_verbs[verb][hook].each do |callback|
          if callback.kind_of? Symbol
            scope.send(callback, *args)
          else
            callback.call(*args)
          end
        end
      end
    end

    def self.before_verb(name, method = nil, &block)
      sym = name.to_s.upcase.intern
      smtp_verbs[sym] = {} unless smtp_verbs.has_key? sym
      smtp_verbs[sym][:before] = [] unless smtp_verbs[sym].has_key? :before
      callback = block_given? ? block : method
      smtp_verbs[sym][:before] << callback
    end

    def self.after_verb(name, method = nil, &block)
      sym = name.to_s.upcase.intern
      smtp_verbs[sym] = {} unless smtp_verbs.has_key? sym
      smtp_verbs[sym][:after] = [] unless smtp_verbs[sym].has_key? :after
      callback = block_given? ? block : method
      smtp_verbs[sym][:after] << callback
    end

    def self.validate_verb(name, method = nil, &block)
      sym = name.to_s.upcase.intern
      smtp_verbs[sym] = {} unless smtp_verbs.has_key? sym
      smtp_verbs[sym][:valid] = [] unless smtp_verbs[sym].has_key? :valid
      callback = block_given? ? block : method
      smtp_verbs[sym][:valid] << callback
    end

    def self.verb(name, method)
      sym = name.to_s.upcase.intern
      smtp_verbs[sym] = {} unless smtp_verbs.has_key? sym
      smtp_verbs[sym][:method] = method
    end

    def self.mail_param(name, method)
      sym = name.to_s.upcase.intern
      mail_parameters[sym] = method
    end

    def run_verb_hook(hook, verb, *args)
      self.class.run_verb_hook_for(hook, verb, self, *args)
    end

    def known_verbs
      self.class.smtp_verbs.map{|k, v| k if v.has_key?(:method)}.compact
    end

    def smtp_verb(verb)
      hooks = self.class.smtp_verbs[verb]
      unless hooks.nil?
        hooks[:method]
      end
    end

    def do_verb(verb, args)
      args = args.to_s.strip
      run_verb_hook :validate, verb, args
      if smtp_verb(verb).nil?
        verb_missing verb, args
      else
        send smtp_verb(verb), args
      end
    end  

    # Lines which do not have a valid verb
    def do_garbage(garbage)
      response_syntax_error :message=>"syntax error - invalid character"
    end

    def verb_missing(verb, parameters)
    end

    def mail_params_valid(params)
      params.each do |name, value|
        return false unless self.class.mail_parameters.has_key? name
      end
      true
    end

    def process_mail_params(params)
      params.each do |name, value|
        send self.class.mail_parameters[name], value
      end
    end
    
    # Does the client support SMTP extensions?
    def esmtp?
      false
    end

    # Did the client successfully authenticate?
    def authenticated?
      false
    end

    # Return the protocol name for use with "WITH" in the Received: header
    def protocol
      # This could return "SMTPS" which is non-standard is two cases:
      #   - Client sends EHLO -> STARTTLS -> HELO sequence
      #   - If using implicit TLS (i.e. non-standard port 465)
      (esmtp? ? "E" : "") + "SMTP" + (secure? ? "S" : "") + (authenticated? ? "A" : "")
    end


    # RFC 5321 § 2.2.2: "verbs [...] are bound by the same rules as EHLO i
    # keywords"; § 4.1.1.1 defines it as /\A[A-Za-z0-9]([A-Za-z0-9-]*)\Z/
    # This splits the verb off and then finds the correct method to call 
    VERB = /\A[A-Za-z0-9]([A-Za-z0-9-]*)\Z/
    def process_line(line)
      k, v = line.chomp.split(' ', 2)
      if k.to_s !~ VERB
          run :do_garbage, line
      end
      k = k.to_s.upcase.tr('-', '_').intern
      run_hook :before_all_verbs, k
      run_verb_hook :before, k
      res = run :do_verb, k, v.to_s.strip
      run_verb_hook :after, k 
      run_hook :after_all_verbs, k
      res
    end

    def parse_params(param_str)
      params = {}
      param_str.split(' ').each do |p|
        k, v = p.split('=', 2)
        k = k.intern
        params[k] = v
      end
      params
    end

    ## Path handling functions
    # From RFC5321 section 4.1.2
    R_Let_dig = '[0-9a-z]'
    R_Ldh_str = "[0-9a-z-]*#{R_Let_dig}"
    R_sub_domain = "#{R_Let_dig}(#{R_Ldh_str})?"
    R_Domain = "#{R_sub_domain}(\\.#{R_sub_domain})*"
    # The RHS domain syntax is explicitly from RFC2821; see
    # http://www.imc.org/ietf-smtp/mail-archive/msg05431.html
    R_RHS_Domain = "#{R_sub_domain}(\\.#{R_sub_domain})+"
    R_At_domain = "@#{R_Domain}"
    R_A_d_l = "#{R_At_domain}(,#{R_At_domain})*"

    R_atext = "[a-z0-9!\#$%&'*+\\/=?^_`{|}~-]"
    R_Atom = "#{R_atext}+"
    R_Dot_string = "#{R_Atom}(\\.#{R_Atom})*"
    R_qtextSMTP = "[\\040-\\041\\043-\\133\\135-\\176]"
    R_quoted_pairSMTP = "\\134[\\040-\\176]"
    R_Quoted_string = "\"(#{R_qtextSMTP}|#{R_quoted_pairSMTP})*\""

    R_Local_part = "(#{R_Dot_string}|#{R_Quoted_string})"

    # This should really be 0-255 with no leading zeros
    R_Snum = "(0|[1-9][0-9]{0,2})"
    R_IPv4_address_literal = "#{R_Snum}(\.#{R_Snum}){3}"
    R_IPv6_hex = "[0-9a-f]{1,4}"
    R_IPv6_full = "#{R_IPv6_hex}(:#{R_IPv6_hex}){7}"
    R_IPv6_comp = "(#{R_IPv6_hex}(:#{R_IPv6_hex}){0,5})?::(#{R_IPv6_hex}(:#{R_IPv6_hex}){0,5})?"
    R_IPv6v4_full = "#{R_IPv6_hex}(:#{R_IPv6_hex}){3}:#{R_IPv4_address_literal}"
    R_IPv6v4_comp = "(#{R_IPv6_hex}(:#{R_IPv6_hex}){0,3})?::(#{R_IPv6_hex}(:#{R_IPv6_hex}){0,3})?:#{R_IPv4_address_literal}"
    R_IPv6_address_literal = "IPv6:(#{R_IPv6_full}|#{R_IPv6_comp}|#{R_IPv6v4_full}|#{R_IPv6v4_comp})"
    # RFC 5321 § 4.1.3 "Standardized-tag MUST be specified in a i
    # Standards-Track RFC and registered with IANA
    # At this point, only "IPv6" has been register, which
    # already handled.  Therefore we are using a slightly simpler regex
    #R_dcontent = "[\\041-\\132\\136-\\176]"
    #R_General_address_literal = "#{R_Ldh_str}:(#{R_dcontent}+)"
    #R_address_literal = "\\[(#{R_IPv4_address_literal}|#{R_IPv6_address_literal}|#{R_General_address_literal})\\]"
    R_address_literal = "\\[(#{R_IPv4_address_literal}|#{R_IPv6_address_literal})\\]"

    R_Mailbox = "#{R_Local_part}@(#{R_RHS_Domain}|#{R_address_literal})"

    # For example, the EHLO/HELO parameter
    DOMAIN_OR_LITERAL = /\A(#{R_Domain}|#{R_address_literal})\Z/i

    R_Path = "<(#{R_A_d_l}:)?#{R_Mailbox}>"

    # For example, an unquoted local part of a mailbox
    DOT_STRING = /\A#{R_Dot_string}\Z/i

    # MatchData[1] is the local part and [4] is the domain or address literal
    MAILBOX = /\A#{R_Mailbox}\Z/i

    # If a string begins with a path (allows for characters after the path)
    # MatchData[1] is the Source Route, [9] is the local part, and 
    # [12] is the domain or address literal
    PATH_PART = /\A#{R_Path}/i

    # Only has path (vs. starts with path)
    # Same MatchData as PATH_PART
    PATH= /\A#{R_Path}\Z/i

    EXCESSIVE_QUOTE = /\134([^\041\134])/

    def valid_address_literal(literal)
      return false unless literal.start_with? '['
      return false unless literal.end_with? ']'
      begin
        IPAddr.new(literal[1..-2])
      rescue ::ArgumentError
        return false
      end
      true
    end

    def split_path(args)
      m = args =~ PATH_PART
      if m.nil?
        [nil, args]
      else
        response = [$~.to_s, $'.strip]
        if $~[12].start_with? '['
          return [nil, args] unless valid_address_literal $~[12]
        end
        response
      end
    end

    def normalize_local_part(local)
      if local.start_with? '"'
        local.gsub!(EXCESSIVE_QUOTE, '\1')
        local = local[1..-2] if local[1..-2] =~ DOT_STRING
      end
      local
    end

    # Remove the leading '<', trailing '>', switch domains lower case and
    # remove unnecessary quoting in the localpart
    def normalize_path(path)
      return '' if path.eql? '<>'
      path =~ PATH
      $~[1].to_s.downcase + normalize_local_part($~[9]) + "@" + $~[12].downcase
    end

    def normalize_mailbox(addr)
      addr =~ MAILBOX
      normalize_local_part($~[1]) + "@" + $~[4].downcase
    end

    # Defined in RFC 3461 § 4, referenced in RFC 5321 § 4.1.2
    R_xchar_list = "\\041-\\052\\054\\074\\076-\\176"
    R_xtext_hexchar = "\\053[0-9A-F]{2}"
    XTEXT = /\A([#{R_xchar_list}]|#{R_xtext_hexchar})*\Z/
    XTEXT_HEXSEQ = /#{R_xtext_hexchar}/
    XTEXT_NOT_XCHAR = /[^#{R_xchar_list}]/

    def from_xtext(str)
      if str =~ XTEXT
        str.gsub!(XTEXT_HEXSEQ) {|s| s[1..2].hex.chr }
      end
    end

    def to_xtext(str)
      str.gsub!(XTEXT_NOT_XCHAR) {|s| '+' + s[0].to_s(16).upcase } 
    end
  end
end
end
