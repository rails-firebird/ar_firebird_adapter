require 'spec_helper'

describe 'populate' do

  around(:each) do |example|
    DatabaseCleaner.cleaning { example.run }
  end

  it '.create' do
    record = SisTest.create!
    expect(record).to be_persisted
    expect(record.id_test).to be_present
  end

  it '.update_all' do
    SisTest.create!
    SisTest.update_all(field_varchar: 'ALTERADO')
    expect(SisTest.first.field_varchar).to eq 'ALTERADO'
  end

  it '.destroy_all' do
    SisTest.create!
    SisTest.destroy_all
    expect(SisTest.all).to be_empty
  end

  it '#update' do
    record = SisTest.create!
    record.update!(field_varchar: 'ALTERADO')
    expect(record.field_varchar).to eq 'ALTERADO'
  end

  it '#destroy' do
    record = SisTest.create!.destroy!
    expect(record).not_to be_persisted
  end

  it 'creates with nested attributes' do
    record = SisTest.create({field_varchar: "Some random text", sis_test_connections_attributes: [{text: "Ever tried, ever failed, don't matter, try again, fail again, fail better"}]})
    expect(record).to be_persisted
    expect(record.sis_test_connections).to be_present
  end

end
