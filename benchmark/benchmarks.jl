using BenchmarkTools
using DynamicDiff: D
using DynamicExpressions: OperatorEnum, @declare_expression_operator
using SymbolicRegression: ComposableExpression, Node
using Random

const SUITE = BenchmarkGroup()

# Helper functions
compute_derivatives(exprs, order) = order == 1 ? [D(expr, 1) for expr in exprs] : 
                                   order == 2 ? [D(D(expr, 1), 2) for expr in exprs] :
                                   [D(D(D(expr, 1), 2), 1) for expr in exprs]

# Simple random expression generator
function gen_expressions(n::Int, size::Int, ops::OperatorEnum, ::Type{T}) where {T}
    rng = MersenneTwister(42)
    vars = ["x1", "x2", "x3"]
    
    [gen_expr(size, ops, vars, T, rng) for _ in 1:n]
end

function gen_expr(size::Int, ops::OperatorEnum, vars, ::Type{T}, rng) where {T}
    if size == 1
        return rand(rng) < 0.7 ? 
            ComposableExpression(Node(T; feature=rand(rng, 1:3)); ops, variable_names=vars) :
            ComposableExpression(Node(T; val=randn(rng, T)); ops, variable_names=vars)
    end
    
    # Get operators (handle API differences)
    unary_ops, binary_ops = hasfield(typeof(ops), :ops) ? ops.ops : (ops.unaops, ops.binops)
    
    if !isempty(unary_ops) && rand(rng) < 0.3
        op = rand(rng, unary_ops)
        return op(gen_expr(size-1, ops, vars, T, rng))
    else
        op = rand(rng, binary_ops)
        left_size = rand(rng, 1:size-1)
        left = gen_expr(left_size, ops, vars, T, rng)
        right = gen_expr(size-1-left_size, ops, vars, T, rng)
        return op(left, right)
    end
end

# Basic operators
basic_ops = OperatorEnum(; binary_operators=(+, -, *, /), unary_operators=(sin, cos))

for T in (Float32, Float64)
    for size in [5, 10, 20]
        exprs = gen_expressions(100, size, basic_ops, T)
        SUITE["basic"][T]["size_$(size)_order_1"] = @benchmarkable compute_derivatives(exprs, 1) setup=(exprs=$exprs)
        SUITE["basic"][T]["size_$(size)_order_2"] = @benchmarkable compute_derivatives(exprs, 2) setup=(exprs=$exprs)
    end
end

# Extended operators  
extended_ops = OperatorEnum(; 
    binary_operators=(+, -, *, /), 
    unary_operators=(sin, cos, sinh, cosh, exp, log, abs, -, inv)
)

for T in (Float32, Float64)
    exprs = gen_expressions(100, 15, extended_ops, T)
    for order in 1:3
        SUITE["extended"][T]["order_$(order)"] = @benchmarkable compute_derivatives(exprs, order) setup=(exprs=$exprs)
    end
end

# Custom operators
my_op(x) = 2x + 1
my_binop(x, y) = x*x + y
@declare_expression_operator(my_op, 1)
@declare_expression_operator(my_binop, 2)

custom_ops = OperatorEnum(; binary_operators=(+, -, *, my_binop), unary_operators=(my_op, sin))

for T in (Float32, Float64)
    exprs = gen_expressions(100, 10, custom_ops, T)
    SUITE["custom"][T]["order_1"] = @benchmarkable compute_derivatives(exprs, 1) setup=(exprs=$exprs)
    SUITE["custom"][T]["order_2"] = @benchmarkable compute_derivatives(exprs, 2) setup=(exprs=$exprs)
end