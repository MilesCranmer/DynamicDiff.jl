module UtilsModule

const subscripts = ('₀', '₁', '₂', '₃', '₄', '₅', '₆', '₇', '₈', '₉')
function subscriptify(number::Integer)
    return join([subscripts[i + 1] for i in reverse(digits(number))])
end

"""
    FixExcept{N}(f::F, args...) where {F}

A callable struct that fixes all arguments in a function call _except_ the `N`-th one.
"""
struct FixExcept{N,F,ARGS<:Tuple} <: Function
    f::F
    args::ARGS
    FixExcept{N}(f::F, args...) where {N,F} = new{N,F,typeof(args)}(f, args)
end

function (f::FixExcept{N})(x) where {N}
    return f.f(f.args[begin:(begin + (N - 2))]..., x, f.args[(begin + (N - 1)):end]...)
end

end
