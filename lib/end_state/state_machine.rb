module EndState
  class StateMachine < SimpleDelegator
    attr_accessor :failure_messages, :success_messages

    def self.store_states_as_strings!
      @store_states_as_strings = true
    end

    def self.store_states_as_strings
      !!@store_states_as_strings
    end

    def self.transition(state_map)
      initial_states = Array(state_map.keys.first)
      final_state = state_map.values.first
      transition_alias = state_map[:as] if state_map.keys.length > 1
      transition = Transition.new(final_state)
      initial_states.each do |state|
        transitions[{ state.to_sym => final_state.to_sym }] = transition
      end
      unless transition_alias.nil?
        events[transition_alias.to_sym] = initial_states.map { |s| { s.to_sym => final_state.to_sym } }
      end
      yield transition if block_given?
    end

    def self.transitions
      @transitions ||= {}
    end

    def self.events
      @events ||= {}
    end

    def self.state_attribute(attribute)
      define_method(:state) { send(attribute.to_sym) }
      define_method(:state=) { |val| send("#{attribute}=".to_sym, val) }
    end

    def self.states
      (start_states + end_states).uniq
    end

    def self.start_states
      transitions.keys.map { |state_map| state_map.keys.first }.uniq
    end

    def self.end_states
      transitions.keys.map { |state_map| state_map.values.first }.uniq
    end

    def object
      __getobj__
    end

    def can_transition?(state, params = {})
      previous_state = self.state.to_sym
      state = state.to_sym
      transition = self.class.transitions[{ previous_state => state }]
      return block_transistion(transition, state, :soft) unless transition
      transition.will_allow? state, params
    end

    def transition(state, params = {}, mode = :soft)
      @failure_messages = []
      @success_messages = []
      previous_state = self.state ? self.state.to_sym : self.state
      state = state.to_sym
      transition = self.class.transitions[{ previous_state => state }]
      return block_transistion(transition, state, mode) unless transition
      return guard_failed(state, mode) unless transition.allowed?(self, params)
      return false unless transition.action.new(self, state).call
      return finalize_failed(state, mode) unless transition.finalize(self, previous_state, params)
      true
    end

    def transition!(state, params = {})
      transition state, params, :hard
    end

    def method_missing(method, *args, &block)
      check_state = method.to_s[0..-2].to_sym
      check_state = state_for_event(check_state) || check_state
      return false if check_state == :__invalid_event__
      return super unless self.class.states.include?(check_state)
      if method.to_s.end_with?('?')
        state.to_sym == check_state
      elsif method.to_s.end_with?('!')
        transition check_state, args[0]
      else
        super
      end
    end

    private

    def state_for_event(event)
      transitions = self.class.events[event]
      return false unless transitions
      return invalid_event(event) unless transitions.map { |t| t.keys.first }.include?(state.to_sym)
      transitions.first.values.first
    end

    def invalid_event(event)
      message = self.class.transitions[self.class.events[event].first].blocked_event_message
      @failure_messages = [message] if message
      :__invalid_event__
    end

    def block_transistion(transition, state, mode)
      if self.class.end_states.include? state
        fail UnknownTransition, "The transition: #{object.state} => #{state} is unknown." if mode == :hard
        return false
      end
      fail UnknownState, "The state: #{state} is unknown."
    end

    def guard_failed(state, mode)
      return false unless mode == :hard
      fail GuardFailed, "The transition to #{state} was blocked: #{failure_messages.join(', ')}"
    end

    def finalize_failed(state, mode)
      return false unless mode == :hard
      fail FinalizerFailed, "The transition to #{state} was rolled back: #{failure_messages.join(', ')}"
    end
  end
end
