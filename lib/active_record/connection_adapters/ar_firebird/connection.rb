module ActiveRecord::ConnectionHandling
  def ar_firebird_connection(config)
    require 'active_record/extensions'
    require 'active_record/internal_metadata_extensions'

    config = config.symbolize_keys.dup.reverse_merge(downcase_names: true, port: 3050, encoding: ActiveRecord::ConnectionAdapters::ArFirebirdAdapter::DEFAULT_ENCODING)

    if config[:host]
      config[:database] = "#{config[:host]}/#{config[:port]}:#{config[:database]}"
    else
      config[:database] = File.expand_path(config[:database], Rails.root)
    end

    connection = ::Fb::Database.new(config).connect

    ActiveRecord::ConnectionAdapters::ArFirebirdAdapter.new(connection, logger, config)
  end
end
