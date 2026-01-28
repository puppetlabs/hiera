# Interpolation Functions

Hiera supports interpolation functions that allow you to manipulate strings and perform pattern matching within your data. These functions can be used in both data values and hierarchy paths in `hiera.yaml`.

## Overview

Interpolation functions use the syntax `%{function_name(arg1, arg2, ...)}`. Arguments can be:

- **Quoted literals**: `'string'` or `"string"`
- **Scope variables**: `$varname` or just `varname`
- **Integers**: `0`, `5`, `-1`, etc.
- **Regex literals**: `/pattern/` with optional flags

## Available Functions

### substring

Extract a portion of a string using 0-based indexing.

**Syntax:**
```
%{substring(string, start)}
%{substring(string, start, count)}
```

**Parameters:**
- `string` - The source string (quoted literal or scope variable)
- `start` - Starting index (0-based, can be negative)
- `count` - Optional number of characters to extract

**Examples:**

```yaml
# In data files
---
# Extract from index 2 to end
slice_to_end: "%{substring('abcdef', 2)}"  # Returns 'cdef'

# Extract 3 characters starting at index 2
slice_with_count: "%{substring('abcdef', 2, 3)}"  # Returns 'cde'

# Using scope variables
node_prefix: "%{substring($certname, 0, 4)}"

# Negative indices (from end of string)
last_three: "%{substring('abcdef', -3)}"  # Returns 'def'
```

**In hiera.yaml hierarchy:**

```yaml
:hierarchy:
  - name: "node certname prefix"
    path: "nodes/%{substring($certname, 0, 4)}.yaml"
  - name: "environment"
    path: "env/%{environment}.yaml"
  - name: "common"
    path: "common.yaml"
```

This would allow grouping nodes by the first 4 characters of their certname.

### match

Test if a string matches a regular expression or contains a substring.

**Syntax:**
```
%{match(string, '/regex/')}
%{match(string, '/regex/flags')}
%{match(string, 'substring')}
%{match(string, $pattern_var)}
```

**Parameters:**
- `string` - The string to test (quoted literal or scope variable)
- `pattern` - A regex literal (`/pattern/`) or a string to search for

**Returns:** `'true'` or `'false'` (as strings)

**Regex Flags:**
- `i` - Case insensitive matching
- `m` - Multiline mode (`.` matches newlines)
- `x` - Extended mode (ignore whitespace in pattern)

**Examples:**

```yaml
# In data files
---
# Simple regex match
is_webserver: "%{match($role, '/^web/')}"

# Case-insensitive match
matches_hello: "%{match('HELLO WORLD', '/hello/i')}"  # Returns 'true'

# Substring contains check
has_db_in_name: "%{match($hostname, 'db')}"

# Complex regex with capture groups
is_valid_version: "%{match($version, '/^(\d+)\.(\d+)\.(\d+)$/')}"
```

**In hiera.yaml hierarchy:**

You can use `match()` results in hierarchy paths, though typically you'd use it in data values for conditional logic:

```yaml
# data/common.yaml
---
# Set a value based on pattern matching
database_type: "%{match($hostname, '/^db/') ? 'primary' : 'replica'}"
```

Note: The ternary operator shown above is not currently supported. Use `match()` to return `'true'`/`'false'` and handle the logic in your Puppet code.

### grep_captures

Extract capture groups from a regex match and join them with a separator.

**Syntax:**
```
%{grep_captures(string, '/regex/')}
%{grep_captures(string, '/regex/', separator)}
%{grep_captures(string, '/regex/', [group_indices])}
%{grep_captures(string, '/regex/', separator, [group_indices])}
```

**Parameters:**
- `string` - The string to match against (quoted literal or scope variable)
- `'/regex/'` - A single-quoted regex literal with capture groups
- `separator` - Optional separator string (default: `''` empty). Auto-detected if 3rd arg is a quoted string.
- `[group_indices]` - Optional array of capture group numbers to extract (default: all groups). Auto-detected if 3rd arg is an array.

**Returns:** The specified capture groups joined by the separator, or empty string if no match.

**Examples:**

```yaml
# In data files
---
# Extract all capture groups concatenated (default behavior)
all_concat: "%{grep_captures('abc-123-def', '/([a-z]+)-(\d+)-([a-z]+)/')}"  # Returns 'abc123def'

# Extract all groups with separator
all_sep: "%{grep_captures('abc-123-def', '/([a-z]+)-(\d+)-([a-z]+)/', '-')}"  # Returns 'abc-123-def'

# Extract specific groups concatenated (3rd arg is array)
selected: "%{grep_captures('abc-123-def', '/([a-z]+)-(\d+)-([a-z]+)/', [1,3])}"  # Returns 'abcdef'

# Extract specific groups with custom separator
parts: "%{grep_captures('abc-123-def', '/([a-z]+)-(\d+)-([a-z]+)/', '_', [1,3])}"  # Returns 'abc_def'

# Parse structured hostname: web01-prod-dc1
# Extract environment and datacenter
env_dc: "%{grep_captures($hostname, '/\w+-(\w+)-(\w+)/', '_', [1,2])}"  # Returns 'prod_dc1'
```

**Use case - Extracting components from structured names:**

```yaml
# data/common.yaml
---
# Hostname format: <role><num>-<env>-<dc>.example.com
# Example: web01-prod-dc1.example.com

# Extract all parts concatenated
all_parts: "%{grep_captures($hostname, '/(\w+)-(\w+)-(\w+)/')}"  # Returns 'web01proddc1'

# Extract environment from hostname (single group)
extracted_env: "%{grep_captures($hostname, '/\w+-(\w+)-\w+/')}"  # Returns 'prod'

# Extract datacenter
extracted_dc: "%{grep_captures($hostname, '/\w+-\w+-(\w+)/')}"  # Returns 'dc1'

# Create a combined identifier with separator
node_id: "%{grep_captures($hostname, '/(\w+)-(\w+)-(\w+)/', '_')}"  # Returns 'web01_prod_dc1'
```

## Practical Examples

### Example 1: Environment-based configuration

```yaml
# hiera.yaml
:hierarchy:
  - name: "node"
    path: "nodes/%{certname}.yaml"
  - name: "role"
    path: "roles/%{role}.yaml"
  - name: "environment"
    path: "env/%{environment}.yaml"
  - name: "common"
    path: "common.yaml"

# data/common.yaml
---
# Use substring to create short identifiers
short_hostname: "%{substring($hostname, 0, 8)}"

# Check if this is a production-like environment
is_production: "%{match($environment, '/^prod/')}"
```

### Example 2: Version-based paths

```yaml
# hiera.yaml
:hierarchy:
  - "os/%{operatingsystem}/%{substring($operatingsystemrelease, 0, 1)}"
  - "os/%{operatingsystem}"
  - common
```

This creates paths like `os/CentOS/7` for CentOS 7.9.2009.

### Example 3: Datacenter detection

```yaml
# data/common.yaml
---
# Detect datacenter from hostname pattern
# Hostnames like: web01-dc1.example.com, db02-dc2.example.com
is_dc1: "%{match($hostname, '/-dc1\./')}"
is_dc2: "%{match($hostname, '/-dc2\./')}"
```

### Version Comparison Functions

Compare semantic versions using `Gem::Version` comparison.

**Syntax:**
```
%{version_gt(version_a, version_b)}   # true if a > b
%{version_gte(version_a, version_b)}  # true if a >= b
%{version_lt(version_a, version_b)}   # true if a < b
%{version_lte(version_a, version_b)}  # true if a <= b
```

**Parameters:**
- `version_a` - First version string (quoted literal or scope variable)
- `version_b` - Second version string (quoted literal or scope variable)

**Returns:** `'true'` or `'false'` (as strings)

**Examples:**

```yaml
# In data files
---
# Check if app version meets minimum requirement
is_compatible: "%{version_gte($app_version, '2.0.0')}"

# Check if OS needs upgrade
needs_upgrade: "%{version_lt($os_version, '8.0')}"

# Compare two scope variables
is_newer: "%{version_gt($installed_version, $required_version)}"
```

**Semantic versioning:**

The functions use Ruby's `Gem::Version` for proper comparison:

```yaml
# Numeric comparison (not string comparison)
correct: "%{version_gte('1.10.0', '1.9.0')}"  # Returns 'true' (1.10 > 1.9)

# Prerelease versions sort before release
prerelease: "%{version_lt('1.0.0.alpha', '1.0.0')}"  # Returns 'true'
```

## Error Handling

- If `substring()` indices are out of range, an empty string is returned.
- If `match()` receives an invalid regex, an error is raised.
- If `grep_captures()` doesn't match, an empty string is returned.
- If `grep_captures()` receives a non-regex pattern, an error is raised.
- If version comparison receives malformed versions, falls back to string comparison.
- Missing scope variables resolve to empty strings.

## Single-Quoted Regex Patterns

You can wrap regex patterns in single quotes (`'/pattern/'`) to gain two benefits:

1. **Curly brace quantifiers**: Allows `{3,5}` without breaking the `%{...}` interpolation
2. **No double-escaping**: Backslashes work naturally without YAML escape doubling

```yaml
# Single-quoted pattern - clean and simple
valid: "%{grep_captures('12345-widget', '/(\d{3,5})-(\w+)/', '_', [1,2])}"

# Without quotes, curly braces break the interpolation
# invalid: "%{grep_captures('12345', /\d{3,5}/)}"  # DON'T do this
```

**Recommended approach** - use single-quoted patterns for cleaner regex:

```yaml
# Single-quoted: no double-escaping needed
clean: "%{match($path, '/a\/b/')}"
digits: "%{match($str, '/\d+/')}"

# Unquoted regex in YAML double-quoted strings requires double-escaping
escaped: "%{match($path, /a\\/b/)}"
```

## Escaping Special Characters (Unquoted Regex)

When using unquoted regex patterns (`/pattern/`) in YAML double-quoted strings:

1. **YAML escaping**: Backslashes must be doubled.
   ```yaml
   # To match a literal slash in regex:
   has_slash: "%{match($path, /a\\/b/)}"  # \\\\ in YAML becomes \\
   ```

2. **Regex escaping**: Standard regex escaping rules apply within the pattern.
   ```yaml
   # Match a literal dot
   has_dot: "%{match($hostname, /\\./)}"`
   ```

**Tip**: Use single-quoted patterns (`'/pattern/'`) to avoid double-escaping complexity.

## Tips

1. **Use in hierarchy paths**: These functions are especially powerful in `hiera.yaml` hierarchy definitions to create dynamic data source paths.

2. **Combine with facts**: Use Facter facts as function arguments to create flexible, fact-driven configurations.

3. **Keep it simple**: While powerful, complex interpolation expressions can be hard to debug. Consider moving complex logic to Puppet code when appropriate.
