# frozen_string_literal: true

module Mongoid
  class Criteria
    module Queryable

      # Adds macro behavior for adding symbol methods.
      module Macroable

        # Adds a method on Symbol for convenience in where queries for the
        # provided operators.
        #
        # @example Add a symbol key.
        #   key :all, "$all
        #
        # @param [ Symbol ] name The name of the method.
        # @param [ Symbol ] strategy The merge strategy.
        # @param [ String ] operator The MongoDB operator.
        # @param [ String ] additional The additional MongoDB operator.
        #
        # @deprecated Will be moved to the mongoid-symbol-operators gem.
        def define_key(name, strategy, operator, additional = nil, &block)
          warning_name = :"symbol_selector_#{name}_deprecated"

          Mongoid::Warnings.warning warning_name,
                                    "The query selector method Symbol##{name} is deprecated and " \
                                    "will be removed in Mongoid 10. Please use either Criteria##{name}, " \
                                    "the #{operator} operator, or add gem 'mongoid-symbol-operators' " \
                                    'to your Gemfile.'

          ::Symbol.define_method(name) do
            Mongoid::Warnings.send(:"warn_#{warning_name}") unless selectors_gem_present?
            Mongoid::Criteria::Queryable::Key.new(self, :"__#{strategy}__", operator, additional, &block)
          end
        end

        def selectors_gem_present?
          return @selectors_gem_present if defined?(@selectors_gem_present)

          @selectors_gem_present = !defined?(Bundler) ||
                                   !!Gem::Specification.find_by_name('mongoid-symbol-operators')
        end

        define_key :all, :union, '$all'

        define_key :elem_match, :override, '$elemMatch'

        define_key :exists, :override, '$exists' do |value|
          Mongoid::Boolean.evolve(value)
        end

        define_key :eq, :override, '$eq'

        define_key :gt, :override, '$gt'

        define_key :gte, :override, '$gte'

        define_key :in, :intersect, '$in'

        define_key :lt, :override, '$lt'

        define_key :lte, :override, '$lte'

        define_key :mod, :override, '$mod'

        define_key :ne, :override, '$ne'

        define_key :near, :override, '$near'

        define_key :near_sphere, :override, '$nearSphere'

        define_key :nin, :intersect, '$nin'

        define_key :not, :override, '$not'

        define_key :with_type, :override, '$type' do |value|
          ::Integer.evolve(value)
        end

        define_key :with_size, :override, '$size' do |value|
          ::Integer.evolve(value)
        end

        define_key :intersects_line, :override, '$geoIntersects', '$geometry' do |value|
          { 'type' => Mongoid::Criteria::Queryable::Selectable::LINE_STRING, 'coordinates' => value }
        end

        define_key :intersects_point, :override, '$geoIntersects', '$geometry' do |value|
          { 'type' => Mongoid::Criteria::Queryable::Selectable::POINT, 'coordinates' => value }
        end

        define_key :intersects_polygon, :override, '$geoIntersects', '$geometry' do |value|
          { 'type' => Mongoid::Criteria::Queryable::Selectable::POLYGON, 'coordinates' => value }
        end

        define_key :within_polygon, :override, '$geoWithin', '$geometry' do |value|
          { 'type' => Mongoid::Criteria::Queryable::Selectable::POLYGON, 'coordinates' => value }
        end

        define_key :within_box, :override, '$geoWithin', '$box'
      end
    end
  end
end
