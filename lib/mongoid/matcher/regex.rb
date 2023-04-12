module Mongoid
  module Matcher
    # In-memory matcher for $regex expression.
    #
    # @see https://www.mongodb.com/docs/manual/reference/operator/query/regex/
    #
    # @api private
    module Regex
      # Returns whether a value satisfies a $regex expression.
      #
      # @param [ true | false ] exists Not used.
      # @param [ String | Array<String> ] value The value to check.
      # @param [ Regexp | BSON::Regexp::Raw ] condition The $regex condition.
      #
      # @return [ true | false ] Whether the value matches.
      #
      # @api private
      module_function def matches?(exists, value, condition)
        condition = convert_condition_to_regexp(condition)
        evaluate_value_against_condition(value, condition)
      end

      # Converts the condition to a regular expression instance.
      #
      # @param [ Regexp | BSON::Regexp::Raw ] condition The condition to convert.
      #
      # @return [ Regexp ] The converted regular expression.
      #
      # @raise [ Errors::InvalidQuery ] If the condition is not a valid regular expression.
      #
      # @api private
      module_function def convert_condition_to_regexp(condition)
        case condition
        when Regexp
          condition
        when BSON::Regexp::Raw
          condition.compile
        else
          # Note that strings must have been converted to a regular expression
          # instance already (with $options taken into account, if provided).
          error_msg = "$regex requires a regular expression argument: "
          truncated_expr = Errors::InvalidQuery.truncate_expr(condition)
          raise Errors::InvalidQuery, "#{error_msg}#{truncated_expr}"
        end
      end

      # Evaluates the value against the regular expression condition.
      #
      # @param [ String | Array<String> ] value The value to check.
      # @param [ Regexp ] condition The regular expression condition.
      #
      # @return [ true | false ] Whether the value matches the condition.
      #
      # @api private
      module_function def evaluate_value_against_condition(value, condition)
        case value
        when Array
          value.any? { |v| v =~ condition }
        when String
          value =~ condition
        else
          false
        end
      end

      # Returns whether an scalar or array value matches a Regexp.
      #
      # @param [ true | false ] exists Not used.
      # @param [ String | Array<String> ] value The value to check.
      # @param [ Regexp ] condition The Regexp condition.
      #
      # @return [ true | false ] Whether the value matches.
      #
      # @api private
      module_function def matches_array_or_scalar?(value, condition)
        if Array === value
          value.any? do |v|
            matches?(true, v, condition)
          end
        else
          matches?(true, value, condition)
        end
      end
    end
  end
end
