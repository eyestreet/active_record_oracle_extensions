module Extensions::ActiveRecord::ConnectionAdapters
  module AbstractAdapter
    def symbolize_foreign_key_constraint_action(constraint_action)
      constraint_action.downcase.gsub(/\s/, '_').to_sym
    end
  end
end
