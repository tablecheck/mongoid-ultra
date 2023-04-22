# frozen_string_literal: true

module Mongoid
  module Errors

    # This exception is raised when attempting to assign a field value
    # which cannot be cast to field type.
    class InvalidAttributeAssignment < MongoidError

      # Create the new invalid attribute assignment error.
      #
      # @example Create the new invalid date error.
      #   InvalidAttributeAssignment.new('Integer', 'String')
      #
      # @param [ String | Class ] field_type The type of the field that was
      #   attempted to be assigned.
      # @param [ String | Class ] value_class The class of the value that was
      #   attempted to be assigned.
      def initialize(field_type, value_class)
        super(compose_message('invalid_attribute_assignment', { field_type: field_type.to_s, value_class: value_class.to_s }))
      end
    end
  end
end
