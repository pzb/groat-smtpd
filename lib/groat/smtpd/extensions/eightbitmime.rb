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

module Groat
module SMTPD
  module Extensions
    module EightBitMIME
      def self.included mod
        puts "Included RFC 1652: 8bit-MIMEtransport"
        mod.ehlo_keyword :"8bitmime"
        mod.mail_param :body, :mail_param_body
        @body_encodings = [] if @body_encodings.nil?
        @body_encodings << "8BITMIME" unless @body_encodings.include? "8BITMIME"
        @body_encodings << "7BIT" unless @body_encodings.include? "7BIT"
        super
      end


      def mail_param_body(param)
        param.upcase!
        unless @body_encodings.include? param
          response_bad_parameter(:message => "Unown mail body type")
        end
        @mail_body = param
        puts "MAIL BODY=#{@mail_body}"
      end
    end
  end
end
end
