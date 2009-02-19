module Extensions::ActiveRecord::ConnectionAdapters
  module OracleAdapter
    def self.included(base)
      base.class_eval do
        alias_method_chain :structure_dump, :extensions
      end
    end


    def structure_dump_with_extensions
      structure = structure_dump_without_extensions
      # handle synonyms
      structure << "-- handle synonyms \n"
      syns = select_all("select synonym_name, table_owner, table_name from user_synonyms").map  do |row|
        "create or replace synonym #{row['synonym_name']} for #{row['table_owner']}.#{row['table_name']};\n"
      end
      structure << syns.join("")
      structure << "\n"
      # indexes
      structure << "-- handle indexes \n"
      idxs = tables.inject([]) do |idxs, table|
        idxds = indexes(table)
        idxds.map! do |idx|
          index_type = idx.unique == true ? "UNIQUE" : ""
          quoted_column_names = idx.columns.map { |e| quote_column_name(e) }.join(", ")
          sql = "CREATE #{index_type} INDEX #{quote_column_name(idx.name)} on #{quote_table_name(idx.table)} (#{quoted_column_names});\n"
        end
        idxs << idxds
      end
      structure << idxs.flatten.join("")
      structure << "\n"
      # primary keys
      structure << "-- handle primary keys \n"
      pidxs = tables.inject([]) do |pidxs, table|
        pidxds = primary_keys(table)
        pidxds.map! do |idx|
          index_type = idx.unique == true ? "UNIQUE" : ""
           pk_name = idx.name
          if idx.name.downcase.include?("sys")
            # come up with a new name
            pk_name = "pk_#{idx.table}"
          end
          quoted_column_names = idx.columns.map { |e| quote_column_name(e) }.join(", ")
          sql = "ALTER TABLE #{quote_table_name(idx.table)} ADD CONSTRAINT #{quote_column_name(pk_name)} PRIMARY KEY (#{quoted_column_names});\n"
        end
        pidxs << pidxds
      end
      structure << pidxs.flatten.join("")
      structure << "\n"
      # handle foreign keys
      structure << "-- handle foreign keys \n"
      fks = select_all("select table_name from user_tables").inject([]) do |fks, table|
        table_name = table.to_a.first.last
        fkcs = foreign_key_constraints(table_name)
        fkcs.map! do |fkcd|
          constraint_name = "#{table_name}_ibfk_#{fkcd.foreign_key}"
          if constraint_name.size > 30
            constraint_name = 'c'+Digest::SHA1.hexdigest(constraint_name)[0,29]
          end
          sql = "ALTER TABLE #{table_name} ADD CONSTRAINT #{constraint_name} FOREIGN KEY (#{fkcd.foreign_key}) REFERENCES #{fkcd.reference_table} (#{fkcd.reference_column})"
          sql << foreign_key_constraint_statement('UPDATE', fkcd.on_update)
          sql << foreign_key_constraint_statement('DELETE', fkcd.on_delete)
          sql << ";\n"
        end
        fks << fkcs
      end
      structure << fks.flatten.join("")
      structure << "\n"
    end

    def primary_keys(table_name, name = nil) #:nodoc:
      result = select_all(<<-SQL, name)
            SELECT lower(i.index_name) as index_name, i.uniqueness, lower(c.column_name) as column_name
              FROM all_indexes i, user_ind_columns c
             WHERE i.table_name = '#{table_name.to_s.upcase}'
               AND c.index_name = i.index_name
               AND i.index_name IN (SELECT uc.index_name FROM user_constraints uc WHERE uc.constraint_type = 'P')
               AND i.owner = sys_context('userenv','session_user')
              ORDER BY i.index_name, c.column_position
          SQL

      current_index = nil
      indexes = []

      result.each do |row|
        if current_index != row['index_name']
          indexes << ActiveRecord::ConnectionAdapters::IndexDefinition.new(table_name, row['index_name'], row['uniqueness'] == "UNIQUE", [])
          current_index = row['index_name']
        end

        indexes.last.columns << row['column_name']
      end

      indexes
    end


    # REFERENTIAL INTEGRITY ====================================

    def disable_referential_integrity(&block) #:nodoc:
      sql_constraints = <<-SQL
      select constraint_name, owner, table_name
        from all_constraints
        where constraint_type='R'
        and status = 'ENABLED' and owner = upper(user)
      SQL
      old_constraints = select_all(sql_constraints)
      begin
        old_constraints.each do |constraint|
          sql_disable = <<-SQL_DISABLE
            ALTER TABLE #{constraint["table_name"]} disable CONSTRAINT #{constraint["constraint_name"]}
          SQL_DISABLE
          execute(sql_disable)
        end
        yield
      ensure
        old_constraints.each do |constraint|
          sql_enable = <<-SQL_ENABLE
            ALTER TABLE #{constraint["table_name"]} MODIFY CONSTRAINT #{constraint["constraint_name"]} ENABLE
          SQL_ENABLE
          execute(sql_enable)
        end
      end
    end


    def foreign_key_constraints(table, name = nil)
      uc  = 'user_constraints'
      ucc = 'user_cons_columns'

      sql =  %Q{SELECT
    c.table_name, cc.column_name,
    r.table_name as rtable_name, rc.column_name as rcolumn_name,
    c.delete_rule
    from
      #{uc} c, #{uc} r, #{ucc} cc, #{ucc} rc
    where
      c.constraint_type = 'R' and
      c.table_name = UPPER('#{table}') and
      c.r_constraint_name = r.constraint_name and
      c.constraint_name = cc.constraint_name and
      r.constraint_name = rc.constraint_name and
      cc.position = rc.position}.gsub(/(\n|^\W+)/, ' ')

      select(sql).collect do |row|
        ForeignKeyConstraintDefinition.new('', row['column_name'].downcase,
                                           row['rtable_name'].downcase, row['rcolumn_name'].downcase,
                                           nil, symbolize_foreign_key_constraint_action(row['delete_rule']))
      end
    end

    def synonyms
      select("select synonym_name, table_owner, table_name from user_synonyms").collect do |row|
        SynonymDefinition.new(row['synonym_name'], row['table_owner'], row['table_name'])
      end
    end

    def add_synonym(name,table_owner,table_name,options = {})
      sql = "create"
      if options[:force] == true
        sql << " or replace"
      end
      sql << " synonym #{name} for #{table_owner}.#{table_name}"
      execute sql
    end

    def drop_synonym(name)
      execute "drop synonym #{name}"
    end

    # Adds a new foreign key constraint to the table.
    #
    # The constrinat will be named after the table and the reference table and column
    # unless you pass +:name+ as an option.
    #
    # options: :name, :on_update, :on_delete
    def foreign_key_constraint_statement(condition, fkc_sym)
      action = { :restrict => 'RESTRICT', :cascade => 'CASCADE', :set_null => 'SET NULL' }[fkc_sym]
      action ? ' ON ' << condition << ' ' << action : ''
    end

    def add_foreign_key_constraint(table_name, foreign_key, reference_table, reference_column, options = {})
      constraint_name = "#{table_name}_ibfk_#{foreign_key}"
      constraint_name = options[:name] unless options[:name].blank?
      # oracle chokes on constraints longer than 30 chars
      if adapter_name =~ /^(oci|oracle)$/i
        constraint_name = 'c'+Digest::SHA1.hexdigest(constraint_name)[0,29]
      end

      sql = "ALTER TABLE #{table_name} ADD CONSTRAINT #{constraint_name} FOREIGN KEY (#{foreign_key}) REFERENCES #{reference_table} (#{reference_column})"
      sql << foreign_key_constraint_statement('UPDATE', options[:on_update])
      sql << foreign_key_constraint_statement('DELETE', options[:on_delete])
      execute sql
    end

    # options: Must enter one of the two options:
    #  1)  :name => the name of the foreign key constraint
    #  2)  :foreign_key => the name of the column for which the foreign key was created
    #      (only if the default constraint_name was used)
    def remove_foreign_key_constraint(table_name, options={})
      constraint_name = options[:name] || "#{table_name}_ibfk_#{foreign_key}"
      raise ArgumentError, "You must specify the constraint name" if constraint_name.blank?
      constraint = 'c'+Digest::SHA1.hexdigest(constraint_name)[0,29]
      execute "ALTER TABLE #{table_name} DROP FOREIGN KEY #{constraint}"
    end


  end
end
