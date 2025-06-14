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

# -----------------------------------------------------------------------------
# API COMPATIBILITY LAYER
# -----------------------------------------------------------------------------
# Historical versions of DynamicExpressions-based libraries accepted evaluation
# of an expression with one vector per feature, e.g.
#
#     ex([x1], [x2], [x3])
#
# where each argument was a 1-element vector (or column).  The new
# DynamicExpressions ≥ 2 API, however, expects a single matrix whose rows
# correspond to features.  To preserve backwards compatibility with the old
# tests we provide the following thin wrapper that converts a vararg of vectors
# to the required matrix form.

import DynamicExpressions: AbstractExpression

function (ex::AbstractExpression)(Xs::AbstractVector...; operators=nothing, kwargs...)
    # If the user passes a single array, fall back to the default implementation.
    if length(Xs) == 1
        return ex(first(Xs); operators=operators, kwargs...)
    end

    # Stack each feature vector vertically to create the expected matrix.
    X = hcat(Xs...)
    return ex(X; operators=operators, kwargs...)
end

end
