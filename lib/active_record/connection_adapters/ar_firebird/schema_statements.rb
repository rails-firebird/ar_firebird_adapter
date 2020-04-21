module ActiveRecord
  module ConnectionAdapters
    module ArFirebird
      module SchemaStatements

        def tables(_name = nil)
          @connection.table_names
        end

        def views
          @connection.view_names
        end

        def indexes(table_name)
          result = query(<<~SQL, "SCHEMA")
            SELECT
              rdb$index_name,
              rdb$unique_flag
            FROM
              rdb$indices
            WHERE
              rdb$relation_name = '#{table_name.upcase}';
          SQL

          result.map do |row|
            index_name = row[0].strip
            unique = row[1] == 1
            columns = query_values(<<~SQL, "SCHEMA")
              SELECT
                rdb$field_name
              FROM
                rdb$index_segments
              WHERE
                rdb$index_name = '#{index_name}'
              ORDER BY
                rdb$field_position
            SQL

            ActiveRecord::ConnectionAdapters::IndexDefinition.new(
              table_name.downcase,
              index_name.downcase,
              unique,
              columns.map(&:strip).map(&:downcase),
            )
          end
        end

        def remove_index(table_name, options = {})
          index_name = index_name_for_remove(table_name, options)
          execute "DROP INDEX #{quote_column_name(index_name)}"
        end

        def foreign_keys(table_name)
          result = query(<<~SQL, "SCHEMA")
            WITH FK_FIELDS AS (
              SELECT
                AA2.RDB$RELATION_NAME,
                AA2.RDB$CONSTRAINT_NAME,
                BB2.RDB$CONST_NAME_UQ AS LINK_UK_OR_PK,
                EE2.RDB$RELATION_NAME AS REFERENCE_TABLE,
                CC2.RDB$FIELD_NAME,
                AA2.RDB$CONSTRAINT_TYPE
              FROM
                RDB$RELATION_CONSTRAINTS AA2
                LEFT JOIN RDB$REF_CONSTRAINTS BB2 ON BB2.RDB$CONSTRAINT_NAME = AA2.RDB$CONSTRAINT_NAME
                LEFT JOIN RDB$INDEX_SEGMENTS CC2 ON CC2.RDB$INDEX_NAME = AA2.RDB$INDEX_NAME
                LEFT JOIN RDB$RELATION_FIELDS DD2 ON DD2.RDB$FIELD_NAME = CC2.RDB$FIELD_NAME AND DD2.RDB$RELATION_NAME = AA2.RDB$RELATION_NAME
                LEFT JOIN RDB$RELATION_CONSTRAINTS EE2 ON EE2.RDB$CONSTRAINT_NAME = BB2.RDB$CONST_NAME_UQ
            )
            SELECT
              AA.RDB$CONSTRAINT_NAME,
              BB.REFERENCE_TABLE,
              BB.FIELDS,
              BB.REFERENCE_FIELDS
            FROM
              RDB$RELATION_CONSTRAINTS AA
              LEFT JOIN (
                SELECT
                  AA1.RDB$RELATION_NAME,
                  AA1.RDB$CONSTRAINT_NAME,
                  AA1.LINK_UK_OR_PK,
                  AA1.REFERENCE_TABLE,
                  (
                    SELECT LIST(TRIM(AA3.RDB$FIELD_NAME), ', ') FROM FK_FIELDS AA3 WHERE AA3.RDB$CONSTRAINT_NAME = AA1.RDB$CONSTRAINT_NAME ROWS 1
                  ) AS FIELDS,
                  (
                    SELECT LIST(TRIM(AA4.RDB$FIELD_NAME), ', ') FROM FK_FIELDS AA4 WHERE AA4.RDB$CONSTRAINT_NAME = AA1.LINK_UK_OR_PK ROWS 1
                  ) AS REFERENCE_FIELDS
                FROM
                  FK_FIELDS AA1
                GROUP BY
                  AA1.RDB$RELATION_NAME,
                  AA1.RDB$CONSTRAINT_NAME,
                  AA1.REFERENCE_TABLE,
                  AA1.LINK_UK_OR_PK
              ) BB ON BB.RDB$RELATION_NAME = AA.RDB$RELATION_NAME AND BB.RDB$CONSTRAINT_NAME = AA.RDB$CONSTRAINT_NAME
            WHERE
              AA.RDB$CONSTRAINT_TYPE = 'FOREIGN KEY'
              AND AA.RDB$RELATION_NAME = '#{table_name.upcase}';
          SQL

          result.map do |row|
            options = {
              column: row[2].downcase,
              name: row[0].strip.downcase,
              primary_key: row[3].downcase
            }

            ActiveRecord::ConnectionAdapters::ForeignKeyDefinition.new(table_name, row[1].strip.downcase, options)
          end
        end

        def change_column(table_name, column_name, type, options = {}) #:nodoc:
          clear_cache!
          type = type_to_sql(type)
          column = column_definitions(table_name.to_sym).find {|column| column["name"] == column_name.to_s }
          if options[:limit]
            type = "#{type.gsub(/\(.*\)/,'')}(#{options[:limit]})"
          end

          sql = []
          if type != column["sql_type"]
            sql << "ALTER COLUMN #{column["name"]} TYPE #{type}"
          end
          execute "ALTER TABLE #{table_name} #{sql.join(', ')}" if sql.any?
        end

        private

          def column_definitions(table_name)
            @connection.columns(table_name)
          end

          def integer_like_primary_key_type(type, options)
            if type == :bigint || options[:limit] == 8
              :bigint
            else
              :int
            end
          end

          def new_column_from_field(table_name, field)
            type_metadata = fetch_type_metadata(field["sql_type"], field)
            ActiveRecord::ConnectionAdapters::ArFirebird::FbColumn.new(
              field["name"],
              field["default"],
              type_metadata,
              field["nullable"],
              table_name,
              nil,
              nil,
              nil,
              field
            )
          end

          def fetch_type_metadata(sql_type, field = "")
            if field['domain'] == ActiveRecord::ConnectionAdapters::ArFirebirdAdapter.boolean_domain[:name]
              cast_type = lookup_cast_type("boolean")
            else
              cast_type = lookup_cast_type(sql_type)
            end
            ActiveRecord::ConnectionAdapters::ArFirebird::SqlTypeMetadata.new(
              sql_type: sql_type,
              type: cast_type.type,
              precision: cast_type.precision,
              scale: cast_type.scale,
              limit: cast_type.limit,
              field: field
            )
          end

      end
    end
  end
end
