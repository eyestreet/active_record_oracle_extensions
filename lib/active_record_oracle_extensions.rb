# ActiveRecordOracleExtensions
ActiveRecord::SchemaDumper.send(:include, Extensions::ActiveRecord::SchemaDumper)
ActiveRecord::ConnectionAdapters::AbstractAdapter.send(:include, Extensions::ActiveRecord::ConnectionAdapters::AbstractAdapter)
ActiveRecord::ConnectionAdapters::SchemaStatements.send(:include, Extensions::ActiveRecord::ConnectionAdapters::SchemaStatements)
ActiveRecord::ConnectionAdapters::OracleAdapter.send(:include, Extensions::ActiveRecord::ConnectionAdapters::OracleAdapter)
