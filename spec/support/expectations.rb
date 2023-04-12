# frozen_string_literal: true

module Mongoid
  module Expectations

    def connection_class
      if defined?(Mongo::Server::ConnectionBase)
        Mongo::Server::ConnectionBase
      else
        # Pre-2.8 drivers
        Mongo::Server::Connection
      end
    end

    def expect_query(number, relax_if_sharded: false)
      relax_if_sharded &&= ClusterConfig.instance.topology == :sharded
      rv = nil
      RSpec::Mocks.with_temporary_scope do
        if number > 0
          matcher = receive(:command_started)
          matcher = matcher.exactly(number).times unless relax_if_sharded
          matcher = matcher.and_call_original
          expect_any_instance_of(connection_class).to matcher
        else
          expect_any_instance_of(connection_class).not_to receive(:command_started)
        end
        rv = yield
      end
      rv
    end

    def expect_no_queries(&block)
      expect_query(0, &block)
    end
  end
end
