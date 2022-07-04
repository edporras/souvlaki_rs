# frozen_string_literal: true

require 'syslogger'

# Logger
module SouvlakiRS
  # log to a local facility
  class Log
    SYS_LOG_FACILITY = Syslog::LOG_LOCAL7

    def initialize(task_name)
      @logger = Syslogger.new(task_name, Syslog::LOG_PID, SYS_LOG_FACILITY)

      # Send messages that are at least of the Logger::WARN level
      @logger.level = Logger::INFO

      @stderr = false
    end

    def verbose(lvl)
      @stderr = lvl
    end

    def info(msg)
      @logger.info msg
      $stderr.puts msg if @stderr
    end

    def warn(msg)
      @logger.warn msg
      $stderr.puts msg if @stderr
    end

    def error(msg)
      @logger.error msg
      $stderr.puts msg if @stderr
    end

  end

  # for syslog - NOTE: using local7 - see log.rb
  SYS_LOG_TASK_NAME = 'souvlaki_rs'

  # the logger instance
  @@_logger = Log.new(SYS_LOG_TASK_NAME)

  def self.logger
    @@_logger
  end
end
