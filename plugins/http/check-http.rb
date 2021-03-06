#!/usr/bin/env ruby
#
# Check HTTP
# ===
#
# Takes either a URL or a combination of host/path/port/ssl, and checks for
# a 200 response (that matches a pattern, if given). Can use client certs.
#
# Copyright 2011 Sonian, Inc.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/http'
require 'net/https'

class CheckHTTP < Sensu::Plugin::Check::CLI

  option :url, :short => '-u URL'
  option :host, :short => '-h HOST'
  option :path, :short => '-p PATH'
  option :port, :short => '-P PORT', :proc => proc {|a| a.to_i }
  option :ssl, :short => '-s', :boolean => true, :default => false
  option :insecure, :short => '-k', :boolean => true, :default => false
  option :cert, :short => '-c FILE'
  option :cacert, :short => '-C FILE'
  option :pattern, :short => '-q PAT'
  option :timeout, :short => '-t SECS', :proc => proc {|a| a.to_i }, :default => 15

  def run
    if config[:url]
      uri = URI.parse(config[:url])
      config[:host] = uri.host
      config[:path] = uri.path
      config[:port] = uri.port
      config[:ssl] = uri.scheme == 'https'
    else
      unless config[:host] and config[:path]
        unknown 'No URL specified'
      end
      config[:port] ||= config[:ssl] ? 443 : 80
    end

    begin
      timeout(config[:timeout]) do
        get_resource
      end
    rescue Timeout::Error
      critical "Connection timed out"
    rescue => e
      critical "Connection error: #{e.message}"
    end
  end

  def get_resource
    http = Net::HTTP.new(config[:host], config[:port])

    if config[:ssl]
      http.use_ssl = true
      if config[:cert]
        cert_data = File.read(config[:cert])
        http.cert = OpenSSL::X509::Certificate.new(cert_data)
        http.key = OpenSSL::PKey::RSA.new(cert_data, nil)
      end
      if config[:cacert]
        http.ca_file = config[:cacert]
      end
      if config[:insecure]
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
    end

    req = Net::HTTP::Get.new(config[:path])
    res = http.request(req)

    case res.code
    when /^2/
      if config[:pattern]
        if res.body =~ /#{config[:pattern]}/
          ok "#{res.code}, found /#{config[:pattern]}/ in #{res.body.size} bytes"
        else
          critical "#{res.code}, did not find /#{config[:pattern]}/ in #{res.body.size} bytes: #{res.body[0...200]}..."
        end
      else
        ok "#{res.code}, #{res.body.size} bytes"
      end
    when /^4/, /^5/
      critical res.code
    else
      warning res.code
    end
  end

end
