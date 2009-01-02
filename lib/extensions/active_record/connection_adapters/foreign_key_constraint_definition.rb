class Extensions::ActiveRecord::ConnectionAdapters::ForeignKeyConstraintDefinition < Struct.new(:name, :foreign_key, :reference_table, :reference_column, :on_update, :on_delete) #:nodoc:
end
