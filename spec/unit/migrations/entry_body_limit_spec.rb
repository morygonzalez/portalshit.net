require 'spec_helper'
require 'active_record/connection_adapters/mysql2_adapter'
require_relative '../../../db/migration/20261011000000_expand_entry_body_limit' unless defined?(ExpandEntryBodyLimit)

describe ExpandEntryBodyLimit do
  subject(:migration) { described_class.new }

  it 'expands only the entry body column' do
    expect(migration).to receive(:change_column).with(:entries, :body, :text, limit: 16_777_215)
    migration.up
  end

  it 'maps the expanded limit to MEDIUMTEXT on MySQL' do
    adapter = ActiveRecord::ConnectionAdapters::Mysql2Adapter.new(adapter: 'mysql2')
    expect(adapter.type_to_sql(:text, limit: described_class::MEDIUMTEXT_LIMIT)).to eq('mediumtext')
    expect(adapter.type_to_sql(:text, limit: described_class::TEXT_LIMIT)).to eq('text')
  end

  it 'allows rollback when all bodies still fit in TEXT' do
    create(:page, body: '山' * 21_845)
    expect(migration).to receive(:change_column).with(:entries, :body, :text, limit: 65_535)
    migration.down
  end

  it 'prevents rollback when multibyte body data exceeds the byte limit' do
    create(:page, body: '山' * 21_846)
    expect(migration).not_to receive(:change_column)
    expect { migration.down }.to raise_error(ActiveRecord::IrreversibleMigration, /65,535/)
  end

  it 'checks bytes with OCTET_LENGTH on MySQL' do
    allow(migration.connection).to receive(:adapter_name).and_return('Mysql2')
    expect(migration).to receive(:select_value).
      with('SELECT 1 FROM entries WHERE OCTET_LENGTH(body) > 65535 LIMIT 1').and_return(1)
    expect(migration).not_to receive(:change_column)
    expect { migration.down }.to raise_error(ActiveRecord::IrreversibleMigration)
  end
end
