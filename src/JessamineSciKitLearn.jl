module JessamineSciKitLearn

using JessamineCLI
using PythonCall

export regression_main

function JessamineCLI.conf_convert(type, value::Py)
    return pyconvert(type, value)
end

end
