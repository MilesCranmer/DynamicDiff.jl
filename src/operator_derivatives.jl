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

"""
    assume_holomorphic(op)

Return `true` to skip runtime Cauchy-Riemann checks for complex derivatives of `op`.
Only extend this trait for operators known to be holomorphic.
"""
assume_holomorphic(::Any) = false  # COV_EXCL_LINE
assume_holomorphic(d::OperatorDerivative) = assume_holomorphic(d.op)
assume_holomorphic(f::FixExcept) = assume_holomorphic(f.f)

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
    return _forward_derivative(d.op, x)
end
function (d::OperatorDerivative{F,D,i})(args::Vararg{Any,D}) where {F,D,i}
    return _forward_derivative(
        FixExcept{i}(d.op, args[begin:(begin + (i - 2))]..., args[(begin + i):end]...),
        args[i],
    )
end

struct FixImaginary{F,T} <: Function
    f::F
    imaginary_part::T
end

function (f::FixImaginary)(real_part)
    return f.f(complex(real_part, f.imaginary_part))
end

struct FixReal{F,T} <: Function
    f::F
    real_part::T
end

function (f::FixReal)(imaginary_part)
    return f.f(complex(f.real_part, imaginary_part))
end

function _forward_derivative(f::F, x) where {F}
    return ForwardDiff.derivative(f, x)
end

function _forward_derivative(f::F, x::Complex{T}) where {F,T}
    return _complex_derivative(f, x, Val(assume_holomorphic(f)))
end

function _complex_derivative(f::F, x::Complex{T}, ::Val{true}) where {F,T}
    derivative = ForwardDiff.derivative(FixImaginary(f, imag(x)), real(x))
    return convert(Complex{T}, derivative)::Complex{T}
end

function _complex_derivative(f::F, x::Complex{T}, ::Val{false}) where {F,T}
    real_derivative = ForwardDiff.derivative(FixImaginary(f, imag(x)), real(x))
    imaginary_derivative = ForwardDiff.derivative(FixReal(f, real(x)), imag(x))
    if !isapprox(imaginary_derivative, im * real_derivative)
        throw(
            DomainError(
                x,
                "operator does not satisfy the Cauchy-Riemann equations at this input; " *
                "define an explicit derivative or extend `assume_holomorphic` only if " *
                "the operator is known to be holomorphic",
            ),
        )
    end
    return convert(Complex{T}, real_derivative)::Complex{T}
end

_known_nonholomorphic_operator(op) = op in (abs, abs2, sign, conj, real, imag)

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
