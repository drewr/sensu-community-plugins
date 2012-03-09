#!/usr/bin/env ruby
#
# Fetch Log Plugin
# ===
#
# This plugin checks a log file for new contents matching a pattern
# and ships them back to a handler.  Much like check-log, it only
# reads what is new.
#
# Copyright 2011 Sonian, Inc.
#
# Released under the same terms as Sensu (the MIT license); see
# LICENSE for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'fileutils'

class FetchLog < Sensu::Plugin::Check::CLI

  BASE_DIR = '/var/cache/fetch-log'

  option :state_auto,
         :description => "Set state file dir automatically using name",
         :short => '-n NAME',
         :long => '--name NAME',
         :proc => proc {|arg| "#{BASE_DIR}/#{arg}" }

  option :state_dir,
         :description => "Dir to keep state files under",
         :short => '-s DIR',
         :long => '--state-dir DIR',
         :default => "#{BASE_DIR}/default"

  option :log_file,
         :description => "Path to log file",
         :short => '-f FILE',
         :long => '--log-file FILE'

  option :pattern,
         :description => "Pattern to match",
         :short => '-q PAT',
         :long => '--pattern PAT'

  def run
    unknown "No log file specified" unless config[:log_file]
    begin
      open_log
    rescue => e
      unknown "Could not open log file: #{e}"
    end
    ok search_log
  end

  def open_log
    state_dir = config[:state_auto] || config[:state_dir]
    @log = File.open(config[:log_file])
    @state_file = File.join(state_dir, File.expand_path(config[:log_file]))
    @bytes_to_skip = begin
      File.open(@state_file) do |file|
        file.readline.to_i
      end
    rescue
      0
    end
  end

  def search_log
    log_file_size = @log.stat.size
    if log_file_size < @bytes_to_skip
      @bytes_to_skip = 0
    end
    bytes_read = 0
    if @bytes_to_skip > 0
      @log.seek(@bytes_to_skip, File::SEEK_SET)
    end
    @log.each_line do |line|
      bytes_read += line.size
      if config[:pattern].nil? || m = line.match(config[:pattern])
        out += line
      end
    end
    FileUtils.mkdir_p(File.dirname(@state_file))
    File.open(@state_file, 'w') do |file|
      file.write(@bytes_to_skip + bytes_read)
    end
    out
  end
end
