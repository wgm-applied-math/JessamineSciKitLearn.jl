using PythonCall

function conf_convert(type, value::Py)
    return pyconvert(type, value)
end
