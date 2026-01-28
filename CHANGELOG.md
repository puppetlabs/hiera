# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- **Interpolation Functions**: New string manipulation functions for use in data values and hierarchy paths.
  - `substring(string, start[, count])`: Extract a portion of a string using 0-based indexing.
    - `%{substring('abcdef', 2)}` returns `'cdef'`
    - `%{substring('abcdef', 2, 3)}` returns `'cde'`
  - `match(string, pattern)`: Test if a string matches a regex or contains a substring.
    - `%{match($role, '/^web/')}` returns `'true'` or `'false'`
    - `%{match($hostname, 'db')}` returns `'true'` if hostname contains 'db'
    - Regex flags supported: `i` (case-insensitive), `m` (multiline), `x` (extended)
  - `grep_captures(string, '/regex/'[, separator][, [groups]])`: Extract capture groups from a regex match.
    - `%{grep_captures('abc-123', '/([a-z]+)-(\d+)/')}` returns `'abc123'` (all groups concatenated)
    - `%{grep_captures('abc-123', '/([a-z]+)-(\d+)/', '-')}` returns `'abc-123'` (all groups with separator)
    - `%{grep_captures('abc-123', '/([a-z]+)-(\d+)/', [1])}` returns `'abc'` (specific groups)
    - `%{grep_captures('abc-123', '/([a-z]+)-(\d+)/', '_', [1,2])}` returns `'abc_123'`
    - Defaults: empty separator `''`, all capture groups
    - Third argument auto-detected: array = groups, quoted string = separator
  - `version_gt(a, b)`, `version_gte(a, b)`, `version_lt(a, b)`, `version_lte(a, b)`: Compare semantic versions.
    - `%{version_gte($app_version, '2.0.0')}` returns `'true'` or `'false'`
    - Uses `Gem::Version` for proper semantic version comparison
    - Handles `1.10.0 > 1.9.0` and prerelease versions correctly

### Changed

- `RX_METHOD_AND_ARG` regex updated to support function arguments containing parentheses (needed for regex capture groups).
- Argument parser now handles array literals `[1,2,3]` for specifying capture group indices.

### Fixed

- Regex literals with escaped slashes (e.g., `/a\/b/`) are now parsed correctly.
- Empty quoted strings (`''` or `""`) are now handled correctly as function arguments.

### Notes

- Single-quoted regex patterns (`'/pattern/'`) are recommended:
  - Support curly brace quantifiers: `'/\d{3,5}/'`
  - No YAML double-escaping needed: `'/\d+/'` instead of `/\\d+/`
