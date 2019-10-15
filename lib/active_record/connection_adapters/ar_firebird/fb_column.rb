module ActiveRecord
  module ConnectionAdapters
    module ArFirebird
      class FbColumn < ActiveRecord::ConnectionAdapters::Column # :nodoc:

        attr_reader :domain
        def initialize(
            name,
            default,
            sql_type_metadata = nil,
            null = true,
            table_name = nil,
            default_function = nil,
            collation = nil,
            comment = nil,
            firebird_options = {}
          )
          @domain = firebird_options.domain
          super(
            name,
            default,
            sql_type_metadata,
            null,
            default_function,
            collation: nil,
            comment: comment
          )
        end
      end
    end
  end
end
