"""
    @cfield spec key default_value

Extract a configuration field from `spec` (a `Dict` or similar)
using `key` as the lookup key, and `default_value` if it's not
present.  The value will be parsed using `parse` and the type of
`default_value`.  Produce syntax of the form

    key = ...

suitable for inclusion as a variable assignment, field in a named
tuple, keyword argument to a function call, etc.

Note that for inclusion in a named tuple or function call,
the `@cfield spec key value` has to be on a line by itself,
so the comma has to go on the next line.
"""
macro cfield(spec, key, default_value)
    :(
        $(esc(key)) = get($(esc(spec)),
                          $(string(key)),
                          $default_value)
    )
end
