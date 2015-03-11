require 'spec_helper'

describe 'Shoryuken::Worker' do
  let(:sqs_queue) { double 'SQS Queue' }
  let(:queue)     { 'shoryuken_later' }
  let(:table)     { 'shoryuken_later' }
  let(:msg_attrs) { { 'shoryuken_class' => { string_value: TestWorker.to_s, data_type: 'String' } } }

  before do
    allow(Shoryuken::Client).to receive(:queues).with(queue).and_return(sqs_queue)
  end

  describe '.perform_later' do
    it 'delays a message for up to 15 minutes in the future' do
      expect(sqs_queue).to receive(:send_message).with('message', { message_attributes: msg_attrs, delay_seconds: 15 * 60 })
        
      TestWorker.perform_later(15 * 60, 'message')
    end

    it 'schedules a message for over 15 minutes in the future' do
      json = JSON.dump(body: 'message', options: {})
      future = Time.now + 15 * 60 + 1
      
      expect(Shoryuken::Later::Client).to receive(:create_item) do |table,attrs|
        expect(attrs[:perform_at]).to be >= future.to_i
        expect(attrs[:shoryuken_args]).to eq(json)
        expect(attrs[:shoryuken_class]).to eq('TestWorker')
      end
      
      TestWorker.perform_later(15 * 60 + 1, 'message')
    end
  end
end
