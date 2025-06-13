using Compat: Fix
using ForwardDiff: ForwardDiff
using DynamicExpressions: DynamicExpressions as DE
using .UtilsModule: subscriptify, FixExcept

"""
    operator_derivative(op::F, ::Val{degree}, ::Val{arg}) where {F,degree,arg}

Create a partial derivative operator of a given function `op` with respect to argument `arg`.

# Arguments
- `op`: The operator to differentiate
- `degree`: The arity of the operator (1 for unary, 2 for binary, etc.)
- `arg`: Which argument to take the derivative with respect to
"""
function operator_derivative(op::F, ::Val{degree}, ::Val{arg}) where {F,degree,arg}
    return OperatorDerivative{F,degree,arg}(op)
end

"""
    OperatorDerivative{F,degree,arg} <: Function

A callable type representing the partial derivative of an operator.
Takes up to `degree` scalar arguments. Returns a scalar.

# Parameters
- `F`: The type of the original operator
- `degree`: The arity of the operator
- `arg`: Which argument to take the derivative with respect to

# Fields
- `op`: The actual function performing the partial derivative.
"""
struct OperatorDerivative{F,degree,arg} <: Function
    op::F
end

function Base.show(io::IO, g::OperatorDerivative{F,degree,arg}) where {F,degree,arg}
    print(io, "∂")
    if degree > 1
        print(io, subscriptify(arg))
    end
    print(io, g.op)
    return nothing
end
Base.show(io::IO, ::MIME"text/plain", g::OperatorDerivative) = show(io, g)

# Generic derivatives:
function (d::OperatorDerivative{F,1,1})(x) where {F}
    return ForwardDiff.derivative(d.op, x)
end
function (d::OperatorDerivative{F,D,i})(args::Vararg{Any,D}) where {F,D,i}
    return ForwardDiff.derivative(
        FixExcept{i}(d.op, args[begin:(begin + (i - 2))]..., args[(begin + i):end]...),
        args[i],
    )
end

#! format: off
# Special Cases (only ones we can implement "closed loops" for)

## Helper Functions
_zero(x) = zero(x)
_one(x) = one(x)
_n_one(x) = -one(x)
# COV_EXCL_START
operator_derivative(::typeof(_zero), ::Val{1}, ::Val{1}) = _zero
operator_derivative(::typeof(_one), ::Val{1}, ::Val{1}) = _zero
operator_derivative(::typeof(_n_one), ::Val{1}, ::Val{1}) = _zero
# COV_EXCL_STOP

## Unary
### Trigonometric
_n_sin(x) = -sin(x)
_n_cos(x) = -cos(x)
# COV_EXCL_START
operator_derivative(::typeof(sin), ::Val{1}, ::Val{1}) = cos
operator_derivative(::typeof(cos), ::Val{1}, ::Val{1}) = _n_sin
operator_derivative(::typeof(_n_sin), ::Val{1}, ::Val{1}) = _n_cos
operator_derivative(::typeof(_n_cos), ::Val{1}, ::Val{1}) = sin
operator_derivative(::typeof(exp), ::Val{1}, ::Val{1}) = exp

### Hyperbolic
operator_derivative(::typeof(sinh), ::Val{1}, ::Val{1}) = cosh
operator_derivative(::typeof(cosh), ::Val{1}, ::Val{1}) = sinh

### Absolute Value
operator_derivative(::typeof(abs), ::Val{1}, ::Val{1}) = sign
operator_derivative(::typeof(sign), ::Val{1}, ::Val{1}) = _zero

### Identity and Negation
operator_derivative(::typeof(identity), ::Val{1}, ::Val{1}) = _one
operator_derivative(::typeof(-), ::Val{1}, ::Val{1}) = _n_one
# COV_EXCL_STOP

### Inverse
struct InvMonomial{C,XNP} <: Function end
function (i::InvMonomial{C,XNP})(x) where {C,XNP}
    return inv(x^XNP) * C
end
operator_derivative(::typeof(inv), ::Val{1}, ::Val{1}) = InvMonomial{-1,2}()
operator_derivative(::InvMonomial{C,XNP}, ::Val{1}, ::Val{1}) where {C,XNP} =
    InvMonomial{-C * XNP,XNP + 1}()

## Binary

### Helper Functions
# TODO: We assume that left/right are symmetric here!
# COV_EXCL_START
_zero(x, _) = zero(x)
_one(x, _) = one(x)
_n_one(x, _) = -one(x)
operator_derivative(::typeof(_zero), ::Val{2}, ::Val{1}) = _zero
operator_derivative(::typeof(_zero), ::Val{2}, ::Val{2}) = _zero
operator_derivative(::typeof(_one), ::Val{2}, ::Val{1}) = _zero
operator_derivative(::typeof(_one), ::Val{2}, ::Val{2}) = _zero
operator_derivative(::typeof(_n_one), ::Val{2}, ::Val{1}) = _zero
operator_derivative(::typeof(_n_one), ::Val{2}, ::Val{2}) = _zero

### Addition
operator_derivative(::typeof(+), ::Val{2}, ::Val{1}) = _one
operator_derivative(::typeof(+), ::Val{2}, ::Val{2}) = _one
operator_derivative(::typeof(-), ::Val{2}, ::Val{1}) = _one
operator_derivative(::typeof(-), ::Val{2}, ::Val{2}) = _n_one
# COV_EXCL_STOP

### Multiplication
_last(_, y) = y
_first(x, _) = x

# COV_EXCL_START
operator_derivative(::typeof(*), ::Val{2}, ::Val{1}) = _last
operator_derivative(::typeof(*), ::Val{2}, ::Val{2}) = _first
operator_derivative(::typeof(_first), ::Val{2}, ::Val{1}) = _one
operator_derivative(::typeof(_first), ::Val{2}, ::Val{2}) = _zero
operator_derivative(::typeof(_last), ::Val{2}, ::Val{1}) = _zero
operator_derivative(::typeof(_last), ::Val{2}, ::Val{2}) = _one
# COV_EXCL_STOP

### Division
struct DivMonomial{C,XP,YNP} <: Function end
function (m::DivMonomial{C,XP,YNP})(x, y) where {C,XP,YNP}
    return C * (XP == 0 ? one(x) : x^XP) / (y^YNP)
end
# ∂₁(x / y) => 1 / y
operator_derivative(::typeof(/), ::Val{2}, ::Val{1}) = DivMonomial{1,0,1}()
# ∂₂(x / y) => -x / y^2
operator_derivative(::typeof(/), ::Val{2}, ::Val{2}) = DivMonomial{-1,1,2}()
operator_derivative(::DivMonomial{C,XP,YNP}, ::Val{2}, ::Val{1}) where {C,XP,YNP} =
    iszero(XP) ? _zero : DivMonomial{C * XP,XP - 1,YNP}()
operator_derivative(::DivMonomial{C,XP,YNP}, ::Val{2}, ::Val{2}) where {C,XP,YNP} =
    DivMonomial{-C * YNP,XP,YNP + 1}()
#! format: on

# COV_EXCL_START
DE.get_op_name(::typeof(_n_sin)) = "-sin"
DE.get_op_name(::typeof(_n_cos)) = "-cos"
# COV_EXCL_STOP

function DE.get_op_name(::InvMonomial{C,XNP}) where {C,XNP}
    num_derivatives = XNP - 1
    return join((("∂" for _ in 1:num_derivatives)..., "inv"))
end
function DE.get_op_name(::DivMonomial{C,XP,YNP}) where {C,XP,YNP}
    num_x_derivatives = 1 - XP
    num_y_derivatives = YNP - 1
    return join((
        ("∂₁" for _ in 1:num_x_derivatives)...,
        ("∂₂" for _ in 1:num_y_derivatives)...,
        "[/]",
    ))
end

# Used to declare if an operator will always evaluate to a constant.
# This gets used in the expression derivative code to automatically
# simplify expressions.
Base.@enum SimplifiesTo::UInt8 NonConstant Zero One NegOne Last First

# COV_EXCL_START
_classify_operator(::F) where {F} = NonConstant
_classify_operator(::typeof(_zero)) = Zero
_classify_operator(::typeof(_one)) = One
_classify_operator(::typeof(_n_one)) = NegOne
_classify_operator(::typeof(_last)) = Last
_classify_operator(::typeof(_first)) = First
# COV_EXCL_STOP
