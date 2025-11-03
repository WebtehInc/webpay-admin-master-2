# Ruby 3.x Compatibility Fix
# Ruby 3.0+ removed Fixnum and Bignum classes, unified them into Integer
# This file provides backwards compatibility for gems that still reference these classes

# Define Fixnum as alias for Integer if not already defined
unless defined?(Fixnum)
  Fixnum = Integer
  puts "  => Ruby 3.x compat: Fixnum = Integer"
end

# Define Bignum as alias for Integer if not already defined
unless defined?(Bignum)
  Bignum = Integer
  puts "  => Ruby 3.x compat: Bignum = Integer"
end

# dry-validation 1.x Compatibility Fix
# dry-validation 0.7.x used Dry::Validation.Schema
# dry-validation 1.x uses Dry::Validation.Contract with different DSL
# This provides a compatibility layer for the old Schema API

require 'dry-validation'

module Dry
  module Validation
    # Compatibility wrapper that converts old Schema DSL to new Contract DSL
    def self.Schema(&block)
      puts "  => dry-validation compat: Schema -> Contract"
      create_legacy_validator(&block)
    end

    # Compatibility wrapper for Form (same as Schema in new API)
    def self.Form(&block)
      puts "  => dry-validation compat: Form -> Contract"
      create_legacy_validator(&block)
    end

    # Common method to create a legacy-compatible validator
    def self.create_legacy_validator(&block)
      # Create a new contract class that mimics the old Schema/Form behavior
      Class.new(Dry::Validation::Contract) do
        # Store the old schema block
        @legacy_block = block

        # Override the call method to work with old-style validation
        def self.call(input)
          # Call the contract with the input
          result = new.call(input)

          # Return an object that mimics the old Schema result API
          SchemaResult.new(result)
        end

        # Parse the old DSL block and convert to new params block
        params do
          # This is a simplified conversion - we'll need to enhance this
          # The block parameter will contain the old-style validation rules
          instance_eval(&@legacy_block) if @legacy_block
        end
      end
    end

    # Wrapper class to make new validation results compatible with old API
    class SchemaResult
      def initialize(contract_result)
        @result = contract_result
      end

      def messages
        # Convert new error format to old format
        @result.errors.to_h
      end

      def success?
        @result.success?
      end

      def failure?
        @result.failure?
      end
    end
  end
end
