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
      puts '111'
      puts ClusterConfig.instance.topology.inspect
      relax_if_sharded &&= ClusterConfig.instance.topology == :sharded
      puts relax_if_sharded.inspect
      rv = nil
      RSpec::Mocks.with_temporary_scope do
        puts '222'
        puts ClusterConfig.instance.topology.inspect
        puts relax_if_sharded.inspect
        if number > 0
          matcher = receive(:command_started)
          matcher = relax_if_sharded ? matcher.at_least(number) : matcher.exactly(number)
          matcher = matcher.times.and_call_original
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
