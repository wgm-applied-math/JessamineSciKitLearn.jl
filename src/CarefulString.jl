function dump_tree(expr, depth=0)
    indent = " "^depth
    etype = typeof(expr)
    s = string(expr)
    println("$indent expr is of type $etype: $s")
    if iscall(expr)
        println("$indent is call")
        op = operation(expr)
        args = arguments(expr)
        println("$indent apply $op:")
        dump_tree(op, depth+1)
        println("$indent to args:")
        for arg in args
            dump_tree(arg, depth+1)
        end
    elseif isexpr(expr)
        println("$indent is expr")
        println("$indent head:")
        dump_tree(head(expr), depth+1)
        println("$indent children:")
        for c in children(expr)
            dump_tree(c, depth+1)
        end
    end
end

function to_careful_string(expr)
    io = IOBuffer()
    careful_string(io, expr)
    return String(take!(io))
end

function careful_string(io, expr; depth=0)
    indent = " "^depth
    etype = typeof(expr)
    s = string(expr)
    println("$indent expr is of type $etype: $s")
    if iscall(expr)
        # println("$indent is call")
        op = operation(expr)
        args = arguments(expr)
        careful_string(io, op, args, depth=depth+1)
    elseif isexpr(expr)
        println("$indent Got expr")
        dump(expr)
    end
end

const BinOp = Union{typeof(+),typeof(-),typeof(*),typeof(^)}

function careful_string(io, op::BinOp, args; depth=0)
    @assert length(args) > 0
    if length(args) == 1
        careful_string(io, op, depth=depth)
        careful_string(io, args[1], depth=depth+1)
    elseif length(args) == 2
        print(io, "(")
        careful_string(io, args[1], depth=depth+1)
        print(io, " ")
        careful_string(io, op, depth=depth)
        print(io, " ")
        careful_string(io, args[2], depth=depth+1)
        print(io, ")")
    else
        print(io, "(")
        careful_string(io, args[1], depth=depth+1)
        print(io, " ")
        careful_string(io, op, depth=depth)
        print(io, " ")
        careful_string(io, op, args[2:end], depth=depth+1)
        print(io, ")")
    end
end

function careful_string(io, f::Function, args; depth=0)
    @assert length(args) > 0
    careful_string(io, f)
    print(io, "(")
    for j in 1:(length(args)-1)
        careful_string(io, args[j], depth=depth+1)
        print(io, ",")
    end
    careful_string(io, args[end], depth=depth+1)
    print(io, ")")
end

function careful_string(io, f::Function; depth=0)
    print(io, f)
end

# For sympy
function careful_string(io, p::typeof(^); depth=0)
    print(io, "**")
end

# For sympy
function careful_string(io, p::typeof(//); depth=0)
    print(io, "/")
end


function careful_string(io, x::Real; depth=0)
    basic = Ryu.writeshortest(Float64(x))
    partsrx = r"(?<m>-?\d+(\.\d*)?)([eE](?<e>-?\d+))?"
    m = match(partsrx, basic)
    @assert m isa RegexMatch
    me = m["e"]
    mm = m["m"]
    if !isnothing(me)
        print(io, "($mm*10")
        careful_string(io, ^, depth=depth)
        print(io, "$me)")
    else
        print(io, basic)
    end
end

function careful_string(io, x::Rational; depth=0)
    p = x.num
    q = x.den
    print(io, "($p")
    careful_string(io, //, depth=0)
    print(io, "$q)")
end

function careful_string(io, x::Integer; depth=0)
    print(io, x)
end

function careful_string(io, x::Number; depth=0)
    print(io, x)
end

function careful_string(io, expr::Num; depth=0)
    v = Symbolics.unwrap(expr)
    careful_string(io, v, depth=depth)
end

function careful_string(io, expr::BasicSymbolic; depth=0)
    if SymbolicUtils.issym(expr)
        raw = string(expr)
        fixed = replace_subscripts(raw)
        print(io, fixed)
    elseif SymbolicUtils.isconst(expr)
        careful_string(io, SymbolicUtils.unwrap_const(expr), depth=depth)
    elseif iscall(expr)
        op = operation(expr)
        args = arguments(expr)
        careful_string(io, op, args, depth=depth+1)
    elseif isexpr(expr)
        println("$indent Got expr")
        dump(expr)
    else
        println(io, "basic symbolic: $expr")
        dump(expr)
    end
end

const SUBSCRIPTS = [
    '\u2080' => '0',   # ₀
    '\u2081' => '1',   # ₁
    '\u2082' => '2',   # ₂
    '\u2083' => '3',   # ₃
    '\u2084' => '4',   # ₄
    '\u2085' => '5',   # ₅
    '\u2086' => '6',   # ₆
    '\u2087' => '7',   # ₇
    '\u2088' => '8',   # ₈
    '\u2089' => '9',   # ₉
]

function replace_subscripts(s)
    replace(s, SUBSCRIPTS...)
end
