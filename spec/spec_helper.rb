require 'bundler/setup'
Bundler.require(:default, :development)

require 'rails'
require 'active_record'

ActiveRecord::Base.establish_connection(
  adapter:  'ar_firebird',
  username: 'SYSDBA',
  password: 'masterkey',
  host: 'db',
  database: '/firebird/data/test.fdb',
  encoding: 'UTF-8'
)

class SisTest < ActiveRecord::Base
  self.table_name = 'sis_test'
  self.primary_key = 'id_test'

  has_many :sis_test_connections
  accepts_nested_attributes_for :sis_test_connections
end

class SisTestConnection < ActiveRecord::Base
  self.table_name = 'sis_test_connection'
  self.primary_key = 'id_test'

  belongs_to :sis_test
end
