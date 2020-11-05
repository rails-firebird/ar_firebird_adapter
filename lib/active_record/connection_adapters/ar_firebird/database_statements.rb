module ActiveRecord::ConnectionAdapters::ArFirebird::DatabaseStatements

  delegate :boolean_domain, to: 'ActiveRecord::ConnectionAdapters::ArFirebirdAdapter'

  DEFAULT_INSERT_VALUE = Arel.sql("DEFAULT").freeze
  private_constant :DEFAULT_INSERT_VALUE

  def default_insert_value(column)
    DEFAULT_INSERT_VALUE
  end

  def insert_fixtures_set(fixture_set, tables_to_delete = [])
    table_deletes = tables_to_delete.map { |table| "DELETE FROM #{quote_table_name(table)}" }
    statements = table_deletes

    with_multi_statements do
      disable_referential_integrity do
        transaction(requires_new: true) do
          execute_batch(statements, "Fixtures Load")
        end
      end
    end
    
    fixture_set.each do |table_name, fixtures|
      next if fixtures.empty?
      fixtures.each do |one_fixture|
        insert_fixture(one_fixture, table_name)
      end
    end
  end

  def build_fixture_sql(fixtures, table_name)
    columns = schema_cache.columns_hash(table_name)

    values_list = fixtures.map do |fixture|
      fixture = fixture.stringify_keys
      unknown_columns = fixture.keys - columns.keys
      if unknown_columns.any?
        raise Fixture::FixtureError, %(table "#{table_name}" has no columns named #{unknown_columns.map(&:inspect).join(', ')}.)
      end
      columns.map do |name, column|
        if fixture.key?(name)
          type = lookup_cast_type_from_column(column)
          with_yaml_fallback(type.serialize(fixture[name]))
        else
          default_insert_value(column)
        end
      end
    end

    table = Arel::Table.new(table_name)
    manager = Arel::InsertManager.new
    manager.into(table)

    values = values_list.shift
    new_values = []
    columns.each_key.with_index { |column, i|
      unless values[i].equal?(DEFAULT_INSERT_VALUE)
        new_values << values[i]
        manager.columns << table[column]
      end
    }
    values_list << new_values

    manager.values = manager.create_values_list(values_list)
    visitor.compile(manager.ast)
  end

  def execute(sql, name = nil)
    sql = sql.encode(encoding, 'UTF-8')

    log(sql, name) do
      ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
        @connection.query(sql)
      end
    end
  end

  def exec_query(sql, name = 'SQL', binds = [], prepare: false)
    sql = sql.encode(encoding, 'UTF-8')

    type_casted_binds = type_casted_binds(binds).map do |value|
      value.encode(encoding) rescue value
    end

    log(sql, name, binds, type_casted_binds) do
      ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
        begin
          result = @connection.execute(sql, *type_casted_binds)
          if result.is_a?(Fb::Cursor)
            fields = result.fields.map(&:name)
            rows = result.fetchall.map do |row|
              row.map do |col|
                col.encode('UTF-8', @connection.encoding) rescue col
              end
            end

            result.close
            ActiveRecord::Result.new(fields, rows)
          else
            result
          end
        rescue Exception => e
          raise e.message.encode('UTF-8', @connection.encoding)
        end
      end
    end
  end

  def begin_db_transaction
    log("begin transaction", nil) { @connection.transaction('READ COMMITTED') }
  end

  def commit_db_transaction
    log("commit transaction", nil) { @connection.commit }
  end

  def exec_rollback_db_transaction
    log("rollback transaction", nil) { @connection.rollback }
  end

  def create_table(table_name, **options)
    super(table_name, options) do |td|
      yield td if block_given?()
      # We have to map the columns to check if we have to change the type
      td.columns.each do |col|
        if col.options[:limit] && col.type == :integer
          col.type = :bigint
        end
      end
    end
    if options[:sequence] != false && options[:id] != false
      sequence_name = options[:sequence] || default_sequence_name(table_name)
      create_sequence(sequence_name)
    end
  end

  def drop_table(table_name, options = {})
    if options[:sequence] != false
      sequence_name = options[:sequence] || default_sequence_name(table_name)
      drop_sequence(sequence_name) if sequence_exists?(sequence_name)
    end

    super
  end

  def create_sequence(sequence_name)
    execute("CREATE SEQUENCE #{sequence_name}") rescue nil
  end

  def drop_sequence(sequence_name)
    execute("DROP SEQUENCE #{sequence_name}") rescue nil
  end

  def sequence_exists?(sequence_name)
    @connection.generator_names.include?(sequence_name)
  end

  def default_sequence_name(table_name, _column = nil)
    "#{table_name}_g01"
  end

  def next_sequence_value(sequence_name)
    @connection.query("SELECT NEXT VALUE FOR #{sequence_name} FROM RDB$DATABASE")[0][0]
  end

  def remove_column(table_name, column_name, type = nil, options = {})
    execute "ALTER TABLE #{table_name} DROP #{column_name}"
  end
end
