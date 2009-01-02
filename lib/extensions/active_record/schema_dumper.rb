module Extensions::ActiveRecord
  module SchemaDumper
    def self.included(base)
      base.class_eval do
        private
        alias_method_chain :tables, :extensions
      end
    end

    def tables_with_extensions(stream)
      tables_without_extensions(stream)
      @connection.tables.sort.each do |tbl|
        next if tbl == "schema_info"
        foreign_key_constraints(tbl, stream)
      end
    end

    def foreign_key_constraints(table, stream)
      keys = @connection.foreign_key_constraints(table)
      keys.each do |key|
        stream.print "  add_foreign_key_constraint #{table.inspect}, #{key.foreign_key.inspect}, #{key.reference_table.inspect}, #{key.reference_column.inspect}, :name => #{key.name.inspect}, :on_update => #{key.on_update.inspect}, :on_delete => #{key.on_delete.inspect}"
        stream.puts
      end
      stream.puts unless keys.empty?
    end
  end
end
