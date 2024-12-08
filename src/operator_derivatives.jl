"""
    OperatorDerivative{F,degree,arg} <: Function

A callable type representing the partial derivative of an operator.
Takes either one (`degree=1`) or two (`degree=2`) scalar arguments. Returns
a scalar.

# Parameters
- `F`: The type of the original operator
- `degree`: The arity of the operator (1 for unary, 2 for binary)
- `arg`: Which argument to take the derivative with respect to

# Fields
- `op`: The actual function performing the partial derivative.
"""
struct OperatorDerivative{F,degree,arg} <: Function
    op::F
end

"""
    operator_derivative(op::F, ::Val{degree}, ::Val{arg}) where {F,degree,arg}

Create an `OperatorDerivative` instance holding the partial derivative of the given operator
for the given argument.

# Arguments
- `op`: The operator to differentiate
- `degree`: The arity of the operator (1 for unary, 2 for binary)
- `arg`: Which argument to take the derivative with respect to
"""
function operator_derivative(op::F, ::Val{degree}, ::Val{arg}) where {F,degree,arg}
    return OperatorDerivative{F,degree,arg}(op)
end

function Base.show(io::IO, g::OperatorDerivative{F,degree,arg}) where {F,degree,arg}
    print(io, "∂")
    if degree == 2
        if arg == 1
            print(io, "₁")
        elseif arg == 2
            print(io, "₂")
        end
    end
    print(io, g.op)
    return nothing
end
Base.show(io::IO, ::MIME"text/plain", g::OperatorDerivative) = show(io, g)

# Generic derivatives:
function (d::OperatorDerivative{F,1,1})(x) where {F}
    return ForwardDiff.derivative(d.op, x)
end
function (d::OperatorDerivative{F,2,1})(x, y) where {F}
    return ForwardDiff.derivative(Fix{2}(d.op, y), x)
end
function (d::OperatorDerivative{F,2,2})(x, y) where {F}
    return ForwardDiff.derivative(Fix{1}(d.op, x), y)
end

#! format: off
# Special Cases
## Unary
_n_sin(x) = -sin(x)
_n_cos(x) = -cos(x)
operator_derivative(::typeof(sin), ::Val{1}, ::Val{1}) = cos
operator_derivative(::typeof(cos), ::Val{1}, ::Val{1}) = _n_sin
operator_derivative(::typeof(_n_sin), ::Val{1}, ::Val{1}) = _n_cos
operator_derivative(::typeof(_n_cos), ::Val{1}, ::Val{1}) = sin
operator_derivative(::typeof(exp), ::Val{1}, ::Val{1}) = exp

## Binary
# TODO: We assume that left/right are symmetric here!
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

### Multiplication
_last(_, y) = y
_first(x, _) = x
operator_derivative(::typeof(*), ::Val{2}, ::Val{1}) = _last
operator_derivative(::typeof(*), ::Val{2}, ::Val{2}) = _first
operator_derivative(::typeof(_first), ::Val{2}, ::Val{1}) = _one
operator_derivative(::typeof(_first), ::Val{2}, ::Val{2}) = _zero
operator_derivative(::typeof(_last), ::Val{2}, ::Val{1}) = _zero
operator_derivative(::typeof(_last), ::Val{2}, ::Val{2}) = _one

### Division
struct DivMonomial{C,XP,YNP} <: Function end
function (m::DivMonomial{C,XP,YNP})(x, y) where {C,XP,YNP}
    return C * (XP == 0 ? one(x) : x^XP) / (y^YNP)
end
operator_derivative(::typeof(/), ::Val{2}, ::Val{1}) = DivMonomial{1,0,1}()
operator_derivative(::typeof(/), ::Val{2}, ::Val{2}) = DivMonomial{-1,1,2}()
operator_derivative(::DivMonomial{C,XP,YNP}, ::Val{2}, ::Val{1}) where {C,XP,YNP} =
    iszero(XP) ? _zero : DivMonomial{C * XP,XP - 1,YNP}()
operator_derivative(::DivMonomial{C,XP,YNP}, ::Val{2}, ::Val{2}) where {C,XP,YNP} =
    DivMonomial{-C * YNP,XP,YNP + 1}()
#! format: on

DE.get_op_name(::typeof(_first)) = "first"
DE.get_op_name(::typeof(_last)) = "last"
DE.get_op_name(::typeof(_n_sin)) = "-sin"
DE.get_op_name(::typeof(_n_cos)) = "-cos"

function DE.get_op_name(::DivMonomial{C,XP,YNP}) where {C,XP,YNP}
    return join(("((x, y) -> ", string(C), "x^", string(XP), "/y^", string(YNP), ")"))
end
