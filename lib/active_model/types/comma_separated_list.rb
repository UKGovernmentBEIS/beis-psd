module ActiveModel
  module Types
    class CommaSeparatedList < ActiveRecord::Type::Value
      def cast(value)
        return value if value.is_a?(Array)
        return nil if value.nil? || value.blank?

        value.split(",").map(&:squish)
      end
    end
  end
end
