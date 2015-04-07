require 'spec_helper'
require 'shoryuken/later/poller'

describe Shoryuken::Later::Poller do
  let(:ddb)       { double 'DynamoDB' }
  let(:body)      { {'foo' => 'bar'} }
  let(:json)      { JSON.dump(body: body, options: {}) }
  let(:table)     { 'shoryuken_later' }

  let(:ddb_item)  do
    {'id' => 'fubar', 'perform_at' => Time.now + 60, 'shoryuken_args' => json, 'shoryuken_class' => 'TestWorker'}
  end

  let(:ddb_item2)  do
    {'id' => 'fubar', 'perform_at' => Time.now + 60, 'shoryuken_args' => json, 'shoryuken_class' => 'TestWorker'}
  end

  before do
    allow(Shoryuken::Later::Client).to receive(:ddb).and_return(ddb)
  end

  subject do
    described_class.new(table)
  end

  describe '#poll' do
    it 'processes items in batches' do
      items = []
      15.times { items << ddb_item }

      expect(Shoryuken::Later::Client).to receive(:items).once.with(table).and_return(items)
      expect_any_instance_of(described_class).to receive(:preprocess_items).twice

      subject.poll
    end

    it 'does not process items when there are no items' do
      items = []
      expect(Shoryuken::Later::Client).to receive(:items).once.with(table).and_return(items)
      expect_any_instance_of(described_class).not_to receive(:process_items)

      subject.poll
    end
  end

  describe '#process_items' do
    it 'enqueues a message if the item could be deleted' do
      allow(Shoryuken::Later::Client).to receive(:delete_item).with(table, ddb_item)

      expect(TestWorker).to receive(:perform_in).once do |time,body,options|
        expect(time   ).to be > Time.now
        expect(body   ).to eq(body)
        expect(options).to be_empty
      end

      subject.send(:process_items, [ddb_item])
    end

    it 'does not enqueue a message if the item could not be deleted' do
      expect(TestWorker).not_to receive(:perform_in)
      expect(Shoryuken::Later::Client).to receive(:delete_item).with(table, ddb_item){ raise Aws::DynamoDB::Errors::ConditionalCheckFailedException.new(nil,nil) }

      subject.send(:process_items, [ddb_item])
    end

    it 'enqueues some messages in a batch when some items can and cannot be deleted' do
      allow(Shoryuken::Later::Client).to receive(:delete_item).once.with(table, ddb_item)
      allow(Shoryuken::Later::Client).to receive(:delete_item).once.with(table, ddb_item2){ raise Aws::DynamoDB::Errors::ConditionalCheckFailedException.new(nil,nil) }

      expect(TestWorker).to receive(:perform_in).once do |time,body,options|
        expect(time   ).to be > Time.now
        expect(body   ).to eq(body)
        expect(options).to be_empty
      end

      subject.send(:process_items, [ddb_item, ddb_item2])
    end
  end
end
