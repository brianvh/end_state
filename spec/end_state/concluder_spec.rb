require 'spec_helper'

module EndState
  describe Concluder do
    subject(:concluder) { Concluder.new(object, state, params) }
    let(:object) { Struct.new('Machine', :failure_messages, :success_messages, :state, :store_states_as_strings).new }
    let(:state) { :a }
    let(:params) { {} }
    before do
      object.failure_messages = []
      object.success_messages = []
    end

    describe '#add_error' do
      it 'adds an error' do
        concluder.add_error('error')
        expect(object.failure_messages).to eq ['error']
      end
    end

    describe '#add_success' do
      it 'adds an success' do
        concluder.add_error('success')
        expect(object.failure_messages).to eq ['success']
      end
    end
  end
end