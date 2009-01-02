require 'digest/sha1'

module Extensions::ActiveRecord::ConnectionAdapters
  module SchemaStatements
    def self.included(base)
      # puts "INCLUDING my SCHEMA statements"
    end
  end
end
