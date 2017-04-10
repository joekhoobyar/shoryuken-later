require 'spec_helper'

describe 'Shoryuken::EnvironmentLoader' do
  let(:tables)     { ['shoryuken_later'] }
  let(:active_support_prefix)     { 'active_support_prefix_test' }
  let(:active_support_delimiter)     { '_' }

  before(:all) do
    @original_tables = Shoryuken::Later.class_variable_get :@@tables
    @original_prefix_config = Shoryuken::Later.active_job_table_name_prefixing = true
  end

  before(:each) do
    Shoryuken::Later.class_variable_set :@@tables, tables
    Shoryuken::Later.active_job_table_name_prefixing = true
  end

  describe 'ActiveJob integration' do
    it 'Prefixes table names with ActiveJob Queue Prefix' do
      stub_const('ActiveJob::Base', Class.new)
      expect(ActiveJob::Base).to receive(:queue_name_prefix).and_return(active_support_prefix)
      expect(ActiveJob::Base).to receive(:queue_name_delimiter).and_return(active_support_delimiter)
      Shoryuken::Later.process_options
      expect(Shoryuken::Later.tables.first).to eq('active_support_prefix_test_shoryuken_later')
    end
  end

  after(:all) do
    Shoryuken::Later.class_variable_set :@@tables, @original_tables
    Shoryuken::Later.active_job_table_name_prefixing = @original_prefix_config
  end
end
