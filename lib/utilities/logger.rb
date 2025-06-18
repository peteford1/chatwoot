# Custom Logger Utility
# Created: 2025-06-10 08:42:00 PDT
# Purpose: Centralized logging for custom code
# 2025-06-10 21:50:00 - Added Utilities namespace for Rails autoloading

module Utilities
  module Logger
    extend ActiveSupport::Concern

    included do
      # Instance methods available to classes that include this module
    end

    private

        def log_info(message, data = nil)
      write_log('INFO', format_message(message, data))
    end

    def log_warn(message, data = nil)
      write_log('WARN', format_message(message, data))
    end

    def log_error(message, data = nil)
      write_log('ERROR', format_message(message, data))
    end

    def log_debug(message, data = nil)
      write_log('DEBUG', format_message(message, data)) if Rails.env.development?
    end

    def format_message(message, data = nil)
      return message.to_s unless data
      "#{message} | #{data.is_a?(Hash) ? data.to_json : data}"
    end

    def write_log(level, message)
      timestamp = Time.current.strftime('%Y-%m-%d %H:%M:%S')
      caller_info = caller_locations(3, 1).first
      file_line = "#{File.basename(caller_info.path)}:#{caller_info.lineno}"
      
      log_message = "[#{timestamp}] [CUSTOM-#{level}] [#{file_line}] #{message}"
      
      # Write to Rails logger
      case level
      when 'ERROR'
        Rails.logger.error(log_message)
      when 'WARN'
        Rails.logger.warn(log_message)
      when 'DEBUG'
        Rails.logger.debug(log_message)
      else
        Rails.logger.info(log_message)
      end
      
      # Also write to custom log file
      write_custom_log(log_message)
    end

    def write_custom_log(message)
      return unless Rails.env.production? || ENV['CUSTOM_LOGGING_ENABLED']
      
      log_dir = Rails.root.join('custom', 'logs')
      FileUtils.mkdir_p(log_dir) unless Dir.exist?(log_dir)
      
      log_file = log_dir.join("custom_#{Date.current.strftime('%Y%m%d')}.log")
      
      File.open(log_file, 'a') do |file|
        file.puts(message)
      end
    rescue => e
      Rails.logger.error "Failed to write custom log: #{e.message}"
    end
  end
end 