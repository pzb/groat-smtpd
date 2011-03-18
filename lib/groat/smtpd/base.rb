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
require 'hooks'
require 'timeout'

module Groat
module SMTPD
  class Response < Exception
    def initialize(args = {})
      @message = args[:message] || "Unknown"
      @terminate = args[:terminate] || false
    end

    def terminate?
      @terminate
    end

    def reply_text
      if @message.is_a? Array
        @message.join("\r\n") + "\r\n"
      else
        @message.to_s + "\r\n"
      end
    end
  end

  class Base
    include Hooks

    @@numinstances = 0

    def initialize
      @response_class = Response
      @instanceid = @@numinstances = @@numinstances + 1
      @s = nil
      @remote_address = nil
      @remote_port = nil
      reset_connection
    end

    def reply(args)
      raise @response_class, args
    end

    def run(method, *args, &block)
      if block_given?
        yield
      else
        send method, *args
      end
    rescue Response => r
      toclient r.reply_text
      not r.terminate?
    end

    def process_line(line)
    end

    def send_greeting
    end

    def service_shutdown
    end

    def reset_connection
    end

    # Nothing in the base implements security
    def secure?
      false
    end

    def set_socket(io)
      @s = io
      x, @remote_port, x, @remote_address = io.peeraddr
    end

    def serve(io)
      set_socket io
      reset_connection
      run :send_greeting
      continue = true
      while continue do
        line = fromclient
        break if line.nil?
        continue = process_line line
      end
    rescue TimeoutError
      run :service_shutdown
    end

    def sockop_timeout(method, arg, wait = 30)
      begin
        timeout(wait){
          return @s.__send__(method, arg)
        }
      end
    end

    def getline
      sockop_timeout(:gets, "\n")
    end

    def getdata(size)
      sockop_timeout(:read, size)
    end

    def fromclient
      line = getline
      log_line(:in, line)
    end

    def log_line(direction, line)
      if direction == :in
        if line.nil?
          puts "#{@instanceid}>/nil"
        else
          puts "#{@instanceid}>>" + line
        end
      else
        if line.nil?
          puts "#{@instanceid}</nil"
        else
          puts "#{@instanceid}<<" + line
        end
      end
      line
    end

    def toclient(msg)
      log_line(:out, msg)
      @s.print(msg)
    end

    def clientdata?
      IO.select([@s], nil, nil, 0.1)
    end
  end
end
end
