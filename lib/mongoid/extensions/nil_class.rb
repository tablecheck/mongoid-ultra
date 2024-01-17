# frozen_string_literal: true

module Mongoid
  module Extensions
    # Adds type-casting behavior to NilClass.
    module NilClass
      # Try to form a setter from this object.
      #
      # @example Try to form a setter.
      #   object.__setter__
      #
      # @return [ nil ] Always nil.
      # @deprecated
      def __setter__
        self
      end
      Mongoid.deprecate(self, :__setter__)

      # Get the name of a nil collection.
      #
      # @example Get the nil name.
      #   nil.collectionize
      #
      # @return [ String ] A blank string.
      delegate :collectionize, to: :to_s
    end
  end
end

NilClass.include Mongoid::Extensions::NilClass
