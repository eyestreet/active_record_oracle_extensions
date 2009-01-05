module Extensions::ActiveRecord
  module AssociationPreload
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      protected
      # patching INNER JOIN syntax because Oracle does not allow the user of as when creating an alias in the naming of tables for an INNER JOIN
      # see http://rails.lighthouseapp.com/projects/8994-ruby-on-rails/tickets/304
      # TODO submit good patch with tests to ROR
      # works with rails 2.2.2
      def preload_has_and_belongs_to_many_association(records, reflection, preload_options={})
        table_name = reflection.klass.quoted_table_name
        id_to_record_map, ids = construct_id_map(records)
        records.each {|record| record.send(reflection.name).loaded}
        options = reflection.options

        conditions = "t0.#{reflection.primary_key_name} #{in_or_equals_for_ids(ids)}"
        conditions << append_conditions(reflection, preload_options)

        associated_records = reflection.klass.find(:all, :conditions => [conditions, ids],
                                                   :include => options[:include],
                                                   :joins => "INNER JOIN #{connection.quote_table_name options[:join_table]} t0 ON #{reflection.klass.quoted_table_name}.#{reflection.klass.primary_key} = t0.#{reflection.association_foreign_key}",
                                                   :select => "#{options[:select] || table_name+'.*'}, t0.#{reflection.primary_key_name} as the_parent_record_id",
                                                   :order => options[:order])

        set_association_collection_records(id_to_record_map, reflection.name, associated_records, 'the_parent_record_id')
      end
    end
  end
end
