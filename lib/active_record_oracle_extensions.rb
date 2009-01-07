# ActiveRecordOracleExtensions
ActiveRecord::SchemaDumper.send(:include, Extensions::ActiveRecord::SchemaDumper)
ActiveRecord::ConnectionAdapters::AbstractAdapter.send(:include, Extensions::ActiveRecord::ConnectionAdapters::AbstractAdapter)
ActiveRecord::ConnectionAdapters::SchemaStatements.send(:include, Extensions::ActiveRecord::ConnectionAdapters::SchemaStatements)

if defined?(ActiveRecord::ConnectionAdapters::OracleAdapter) then
  ActiveRecord::ConnectionAdapters::OracleAdapter.send(:include, Extensions::ActiveRecord::ConnectionAdapters::OracleAdapter)
end

if defined?(ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter) then
  ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.send(:include, Extensions::ActiveRecord::ConnectionAdapters::OracleAdapter)
end

# patching habtm preload fetch that tries to use add AS before a table alias
ActiveRecord::Base.send(:include, Extensions::ActiveRecord::AssociationPreload)
