require 'hiera/backend'
require 'hiera/recursive_guard'


class Hiera::InterpolationInvalidValue < StandardError; end

# @api private
class Hiera::Interpolate
  RX_INTERPOLATION = /%\{([^\}]*)\}/
  RX_ONLY_INTERPOLATION = /^%\{([^\}]*)\}$/
  RX_METHOD_AND_ARG = /^(\w+)\((.*)\)$/

  EMPTY_INTERPOLATIONS = {
    '' => true,
    '::' => true,
    '""' => true,
    "''" => true,
    '"::"' => true,
    "'::'" => true
  }.freeze

  INTERPOLATION_METHODS = {
    'hiera' => :hiera_interpolate,
    'scope' => :scope_interpolate,
    'literal' => :literal_interpolate,
    'alias' => :alias_interpolate,
    'substring' => :substring_interpolate,
    'match' => :match_interpolate,
    'grep_captures' => :grep_captures_interpolate,
    'version_gt' => :version_gt_interpolate,
    'version_gte' => :version_gte_interpolate,
    'version_lt' => :version_lt_interpolate,
    'version_lte' => :version_lte_interpolate
  }.freeze

  class << self
    # These two patterns are never used but kept here anyway since they used to be public and therefore
    # must be considered API. The class is now marked @api private and these should be removed in a
    # future version
    #
    # @deprecated
    INTERPOLATION = /%\{([^\}]*)\}/

    # @deprecated
    METHOD_INTERPOLATION = /%\{(scope|hiera|literal|alias)\(['"]([^"']*)["']\)\}/

    def interpolate(data, scope, extra_data, context)
      if data.is_a?(String)
        # Wrapping do_interpolation in a gsub block ensures we process
        # each interpolation site in isolation using separate recursion guards.
        new_context = context.nil? ? {} : context.clone
        new_context[:recurse_guard] ||= Hiera::RecursiveGuard.new

        result = data.dup
        offset = 0

        find_interpolations(data).each do |start_pos, end_pos, inner|
          match = "%{#{inner}}"
          (interp_val, interpolate_method) = do_interpolation(match, scope, extra_data, new_context)

          if (interpolate_method == :alias_interpolate) && !interp_val.is_a?(String)
            return interp_val if data == match
            raise Hiera::InterpolationInvalidValue, "Cannot call alias in the string context"
          end

          replacement = interp_val.to_s
          result[start_pos + offset, end_pos - start_pos + 1] = replacement
          offset += replacement.length - (end_pos - start_pos + 1)
        end

        result
      else
        data
      end
    end

    def find_interpolations(data)
      results = []
      i = 0
      while i < data.length - 1
        if data[i] == '%' && data[i + 1] == '{'
          start_pos = i
          inner_start = i + 2
          j = inner_start
          in_single_quote = false
          in_func_args = false
          first_close_brace = nil

          while j < data.length
            ch = data[j]

            # Remember first } position for fallback
            first_close_brace ||= j if ch == '}'

            # Track if we're inside function arguments (after opening paren)
            if ch == '(' && !in_single_quote
              in_func_args = true
            elsif ch == ')' && !in_single_quote
              in_func_args = false
            end

            # Only track single quotes inside function arguments
            # This allows patterns like '/\d{3,5}/' while preserving
            # error detection for malformed keys like %{'the.key"}
            if in_func_args
              if in_single_quote
                in_single_quote = false if ch == "'"
              elsif ch == "'"
                in_single_quote = true
              end
            end

            if ch == '}' && !in_single_quote
              inner = data[inner_start...j]
              results << [start_pos, j, inner]
              i = j
              break
            end
            j += 1
          end

          # If we reached end of string with unclosed quote, fall back to first }
          # This allows downstream validation to catch the quote mismatch error
          if j >= data.length && in_single_quote && first_close_brace
            inner = data[inner_start...first_close_brace]
            results << [start_pos, first_close_brace, inner]
            i = first_close_brace
          end
        end
        i += 1
      end
      results
    end
    private :find_interpolations

    def do_interpolation(data, scope, extra_data, context)
      # Extract interpolation variable - try smart parser first, fall back to regex
      interpolation_variable = nil
      if data.is_a?(String)
        if data.start_with?('%{') && data.end_with?('}')
          # Already extracted by find_interpolations
          interpolation_variable = data[2...-1]
        elsif (match = data.match(RX_INTERPOLATION))
          interpolation_variable = match[1]
        end
      end

      if interpolation_variable
        # HI-494
        return ['', nil] if EMPTY_INTERPOLATIONS[interpolation_variable.strip]

        context[:recurse_guard].check(interpolation_variable) do
          interpolate_method, key = get_interpolation_method_and_key(interpolation_variable, context)
          interpolated_data = send(interpolate_method, data, key, scope, extra_data, context)

          # Halt recursion if we encounter a literal.
          return [interpolated_data, interpolate_method] if interpolate_method == :literal_interpolate

          [do_interpolation(interpolated_data, scope, extra_data, context)[0], interpolate_method]
        end
      else
        [data, nil]
      end
    end
    private :do_interpolation

    def get_interpolation_method_and_key(interpolation_variable, context)
      if (match = interpolation_variable.match(RX_METHOD_AND_ARG))
        Hiera.warn('Use of interpolation methods in hiera configuration file is deprecated') if context[:is_interpolate_config]
        method = match[1]
        method_sym = INTERPOLATION_METHODS[method]
        raise Hiera::InterpolationInvalidValue, "Invalid interpolation method '#{method}'" unless method_sym
        arg = match[2]
        return [method_sym, arg] if %w[substring match grep_captures version_gt version_gte version_lt version_lte].include?(method)
        match_data = arg.match(Hiera::QUOTED_KEY)
        raise Hiera::InterpolationInvalidValue, "Argument to interpolation method '#{method}' must be quoted, got '#{arg}'" unless match_data
        [method_sym, match_data[1] || match_data[2]]
      else
        [:scope_interpolate, interpolation_variable]
      end
    end
    private :get_interpolation_method_and_key

    def scope_interpolate(data, key, scope, extra_data, context)
      segments = Hiera::Util.split_key(key) { |problem| Hiera::InterpolationInvalidValue.new("#{problem} in interpolation expression: #{data}") }
      catch(:no_such_key) { return Hiera::Backend.qualified_lookup(segments, scope, key) }
      catch(:no_such_key) { Hiera::Backend.qualified_lookup(segments, extra_data, key) }
    end
    private :scope_interpolate

    def hiera_interpolate(data, key, scope, extra_data, context)
      Hiera::Backend.lookup(key, nil, scope, context[:order_override], :priority, context)
    end
    private :hiera_interpolate

    def literal_interpolate(data, key, scope, extra_data, context)
      key
    end
    private :literal_interpolate

    def substring_interpolate(data, key, scope, extra_data, context)
      args = parse_substring_args(key, data)
      value = resolve_substring_value(args[0], scope, extra_data, data)
      start = resolve_substring_integer(args[1], scope, extra_data, data)

      if args.length == 3
        count = resolve_substring_integer(args[2], scope, extra_data, data)
        result = value[start, count]
      else
        result = value[start..-1]
      end
      result.nil? ? '' : result
    end
    private :substring_interpolate

    def match_interpolate(data, key, scope, extra_data, context)
      args = parse_match_args(key, data)
      value = resolve_substring_value(args[0], scope, extra_data, data)
      pattern = args[1]

      regex = parse_regex_literal(pattern, data)
      matched = if regex
        !(value.match(regex)).nil?
      else
        needle = resolve_substring_value(pattern, scope, extra_data, data)
        value.include?(needle)
      end

      matched ? 'true' : 'false'
    end
    private :match_interpolate

    def grep_captures_interpolate(data, key, scope, extra_data, context)
      args = parse_grep_captures_args(key, data)
      value = resolve_substring_value(args[0], scope, extra_data, data)
      pattern = args[1]

      regex = parse_regex_literal(pattern, data)
      raise Hiera::InterpolationInvalidValue, "grep_captures requires a regex pattern in interpolation expression: #{data}" unless regex

      match_result = value.match(regex)
      return '' if match_result.nil?

      # Determine separator and capture group indices
      # Default: empty separator, all capture groups
      separator = ''
      group_indices = (1..match_result.length - 1).to_a

      if args.length >= 3
        third_arg = args[2].strip
        if third_arg.start_with?('[')
          # Third arg is array literal - use default separator
          group_indices = parse_array_literal(args[2], scope, extra_data, data)
        else
          # Third arg is separator (quoted string)
          separator = resolve_substring_value(args[2], scope, extra_data, data)
          if args.length >= 4
            # Fourth arg is array literal of capture group indices: [1,2,4]
            group_indices = parse_array_literal(args[3], scope, extra_data, data)
          end
        end
      end

      # Extract specified capture groups
      captures = group_indices.map do |idx|
        match_result[idx].to_s
      end

      captures.join(separator)
    end
    private :grep_captures_interpolate

    def parse_grep_captures_args(arg_string, data)
      args = split_function_args(arg_string)
      unless args.length >= 2
        raise Hiera::InterpolationInvalidValue, "grep_captures requires at least 2 arguments (string, regex) in interpolation expression: #{data}"
      end
      if args[0].empty? || args[1].empty?
        raise Hiera::InterpolationInvalidValue, "grep_captures contains an empty required argument in interpolation expression: #{data}"
      end
      args
    end
    private :parse_grep_captures_args

    def version_gt_interpolate(data, key, scope, extra_data, context)
      versioncmp_interpolate(data, key, scope, extra_data, :>)
    end
    private :version_gt_interpolate

    def version_gte_interpolate(data, key, scope, extra_data, context)
      versioncmp_interpolate(data, key, scope, extra_data, :>=)
    end
    private :version_gte_interpolate

    def version_lt_interpolate(data, key, scope, extra_data, context)
      versioncmp_interpolate(data, key, scope, extra_data, :<)
    end
    private :version_lt_interpolate

    def version_lte_interpolate(data, key, scope, extra_data, context)
      versioncmp_interpolate(data, key, scope, extra_data, :<=)
    end
    private :version_lte_interpolate

    def versioncmp_interpolate(data, key, scope, extra_data, operator)
      args = parse_versioncmp_args(key, data)
      version_a = resolve_substring_value(args[0], scope, extra_data, data)
      version_b = resolve_substring_value(args[1], scope, extra_data, data)

      result = compare_versions(version_a, version_b, operator)
      result ? 'true' : 'false'
    end
    private :versioncmp_interpolate

    def parse_versioncmp_args(arg_string, data)
      args = split_function_args(arg_string)
      unless args.length == 2
        raise Hiera::InterpolationInvalidValue, "version comparison requires 2 arguments in interpolation expression: #{data}"
      end
      if args.any? { |a| a.empty? }
        raise Hiera::InterpolationInvalidValue, "version comparison contains an empty argument in interpolation expression: #{data}"
      end
      args
    end
    private :parse_versioncmp_args

    def compare_versions(version_a, version_b, operator)
      # Use Gem::Version for proper semantic version comparison
      # It handles versions like "1.2.3", "1.2.3-beta", "1.2.3.4", etc.
      begin
        gem_a = Gem::Version.new(version_a)
        gem_b = Gem::Version.new(version_b)
        gem_a.send(operator, gem_b)
      rescue ArgumentError
        # Fall back to string comparison if versions are malformed
        version_a.send(operator, version_b)
      end
    end
    private :compare_versions

    def parse_array_literal(token, scope, extra_data, data)
      value = token.to_s.strip
      unless value.start_with?('[') && value.end_with?(']')
        raise Hiera::InterpolationInvalidValue, "grep_captures capture groups must be an array literal like [1,2,3] in interpolation expression: #{data}"
      end

      inner = value[1...-1]
      return [1] if inner.strip.empty?

      inner.split(',').map do |item|
        resolve_substring_integer(item.strip, scope, extra_data, data)
      end
    end
    private :parse_array_literal

    def parse_match_args(arg_string, data)
      args = split_function_args(arg_string)
      unless args.length == 2
        raise Hiera::InterpolationInvalidValue, "match requires 2 arguments in interpolation expression: #{data}"
      end
      if args.any? { |a| a.empty? }
        raise Hiera::InterpolationInvalidValue, "match contains an empty argument in interpolation expression: #{data}"
      end
      args
    end
    private :parse_match_args

    def parse_substring_args(arg_string, data)
      args = split_function_args(arg_string)
      unless args.length == 2 || args.length == 3
        raise Hiera::InterpolationInvalidValue, "substring requires 2 or 3 arguments in interpolation expression: #{data}"
      end
      if args.any? { |a| a.empty? }
        raise Hiera::InterpolationInvalidValue, "substring contains an empty argument in interpolation expression: #{data}"
      end
      args
    end
    private :parse_substring_args

    def split_function_args(arg_string)
      input = arg_string.to_s
      args = []
      current = ''
      in_single_quote = false
      in_double_quote = false
      in_regex = false
      in_array = false
      in_curly = 0
      escaped = false
      regex_escaped = false

      input.each_char do |ch|
        if escaped
          current << ch
          escaped = false
          next
        end

        if ch == '\\'
          current << ch
          escaped = true
          next
        end

        if in_single_quote
          current << ch
          in_single_quote = false if ch == "'"
          next
        end

        if in_double_quote
          current << ch
          in_double_quote = false if ch == '"'
          next
        end

        if in_regex
          current << ch
          if ch == '/' && !regex_escaped
            in_regex = false
          end
          regex_escaped = (ch == '\\' && !regex_escaped)
          next
        end

        if in_array
          current << ch
          in_array = false if ch == ']'
          next
        end

        if in_curly > 0
          current << ch
          in_curly += 1 if ch == '{'
          in_curly -= 1 if ch == '}'
          next
        end

        case ch
        when "'"
          current << ch
          in_single_quote = true
        when '"'
          current << ch
          in_double_quote = true
        when '/'
          current << ch
          in_regex = current.strip == '/'
        when '['
          current << ch
          in_array = true
        when '{'
          current << ch
          in_curly = 1
        when ','
          args << current.strip
          current = ''
        else
          current << ch
        end
      end

      args << current.strip
      args
    end
    private :split_function_args

    def find_closing_regex_delimiter(value)
      escaped = false
      (1...value.length).each do |i|
        ch = value[i]
        if escaped
          escaped = false
          next
        end
        if ch == '\\'
          escaped = true
          next
        end
        return i if ch == '/'
      end
      nil
    end
    private :find_closing_regex_delimiter

    def parse_regex_literal(token, data)
      value = token.to_s.strip

      # Support quoted regex: '/pattern/' or "/pattern/"
      if (value.start_with?("'") && value.end_with?("'")) ||
         (value.start_with?('"') && value.end_with?('"'))
        inner = value[1...-1].strip
        return nil unless inner.start_with?('/')
        value = inner
      end

      return nil unless value.start_with?('/')

      closing = find_closing_regex_delimiter(value)
      return nil if closing.nil? || closing == 0

      pattern = value[1...closing]
      flags = value[(closing + 1)..] || ''

      options = 0
      flags.each_char do |flag|
        case flag
        when 'i'
          options |= Regexp::IGNORECASE
        when 'm'
          options |= Regexp::MULTILINE
        when 'x'
          options |= Regexp::EXTENDED
        else
          raise Hiera::InterpolationInvalidValue, "Invalid regex option '#{flag}' in interpolation expression: #{data}"
        end
      end

      Regexp.new(pattern, options)
    rescue RegexpError
      raise Hiera::InterpolationInvalidValue, "Invalid regex '#{token}' in interpolation expression: #{data}"
    end
    private :parse_regex_literal

    def resolve_substring_value(token, scope, extra_data, data)
      match_data = token.match(Hiera::QUOTED_KEY)
      return (match_data[1] || match_data[2]).to_s if match_data

      # Handle empty quoted strings which QUOTED_KEY doesn't match
      return '' if token == "''" || token == '""'

      name = token.sub(/^\$/, '')
      segments = Hiera::Util.split_key(name) { |problem| Hiera::InterpolationInvalidValue.new("#{problem} in interpolation expression: #{data}") }
      value = catch(:no_such_key) { Hiera::Backend.qualified_lookup(segments, scope, name) }
      return value.to_s unless value.nil?

      value = catch(:no_such_key) { Hiera::Backend.qualified_lookup(segments, extra_data, name) }
      value.to_s
    end
    private :resolve_substring_value

    def resolve_substring_integer(token, scope, extra_data, data)
      match_data = token.match(Hiera::QUOTED_KEY)
      token = (match_data[1] || match_data[2]) if match_data
      token = token.to_s

      if token =~ /^\$/
        token = token.sub(/^\$/, '')
        segments = Hiera::Util.split_key(token) { |problem| Hiera::InterpolationInvalidValue.new("#{problem} in interpolation expression: #{data}") }
        token = catch(:no_such_key) { return Integer(Hiera::Backend.qualified_lookup(segments, scope, token).to_s) }
        token = catch(:no_such_key) { Hiera::Backend.qualified_lookup(segments, extra_data, token) }
      end

      Integer(token.to_s)
    rescue ArgumentError
      raise Hiera::InterpolationInvalidValue, "substring requires integer arguments in interpolation expression: #{data}"
    end
    private :resolve_substring_integer

    def alias_interpolate(data, key, scope, extra_data, context)
      Hiera::Backend.lookup(key, nil, scope, context[:order_override], :priority, context)
    end
    private :alias_interpolate
  end
end
