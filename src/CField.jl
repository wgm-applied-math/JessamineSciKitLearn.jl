"""
    @cfield spec key default_value etype

Extract a configuration field from `spec` (a `Dict` or similar)
using `key` as the lookup key, and `default_value` if it's not
present.  Strings are be parsed using `parse` and `eval`.
Results are converted to `etype`, which defaults to the type of
`default_value`.  Produce syntax of the form

    key = ...

suitable for inclusion as a variable assignment, field in a named
tuple, keyword argument to a function call, etc.

Note that for inclusion in a named tuple or function call,
the `@cfield spec key value` has to be on a line by itself,
so the comma has to go on the next line.

If `etype` is omitted, it defaults to the type of `default_value`.
"""
macro cfield(spec, key, default_value, etype)
    :(
        $(esc(key)) = get_or_parse(
            $(esc(spec)),
            $(string(key)),
            $default_value,
            $etype)
    )
end
macro cfield(spec, key, default_value)
    :(
        $(esc(key)) = get_or_parse(
            $(esc(spec)),
            $(string(key)),
            $default_value)
    )
end

"""
    get_or_parse(spec, key, default_value, etype=typeof(default_value))

Try to get the value corresponding to `key` from the dictionary
`spec`.  If the result is `nothing`, return that.  If the result
is a string and `etype` is not a string type, `parse` the value
into the specified type.  If the result is some other type, `convert`
the value to the specified type.
"""
function get_or_parse(spec::AbstractDict, key, default_value, etype=typeof(default_value))
    try
        value = get(spec, key, default_value)
        if isa(value, etype)
            return value
        elseif !isa(default_value, AbstractString) && isa(value, AbstractString)
            # Got a string that needs to be parsed
            p_val = Meta.parse(etype)
            e_val = eval(p_val)
            c_val = conf_convert(etype, e_val)
            return c_val
        elseif isnothing(value)
            return default_value
        else
            # Got something of the wrong type
            c_val = conf_convert(etype, value)
            return c_val
        end
    catch e
        @error "get_or_parse: Exception while looking up key=$key, default_value=$default_value, etype=$etype:" exception=(
            e, catch_backtrace())
        rethrow()
    end
end

"""
    conf_convert(type, value)

Use `convert` or `pyconvert` to convert `value` to `type`.
"""
function conf_convert(type, value)
    return convert(type, value)
end

function conf_convert(type, value::Py)
    return pyconvert(type, value)
end
