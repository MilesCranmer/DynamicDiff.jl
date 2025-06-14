using BenchmarkTools
using DynamicDiff: D
using DynamicExpressions: OperatorEnum, @declare_expression_operator, AbstractExpression
using SymbolicRegression: ComposableExpression, Node
using Random

const SUITE = BenchmarkGroup()

# Helper functions
compute_derivatives(exprs, order) = order == 1 ? [D(expr, 1) for expr in exprs] : 
                                   order == 2 ? [D(D(expr, 1), 2) for expr in exprs] :
                                   [D(D(D(expr, 1), 2), 1) for expr in exprs]

# Simple random expression generator that adapts to available operators
function gen_expressions(n::Int, ops::OperatorEnum, ::Type{T}) where {T}
    rng = MersenneTwister(42)
    vars = ["x1", "x2", "x3"]
    
    expressions = []
    for _ in 1:n
        # Create base variables
        x1 = ComposableExpression(Node(T; feature=1); operators=ops, variable_names=vars)
        x2 = ComposableExpression(Node(T; feature=2); operators=ops, variable_names=vars)
        x3 = ComposableExpression(Node(T; feature=3); operators=ops, variable_names=vars)
        c = ComposableExpression(Node(T; val=randn(rng, T)); operators=ops, variable_names=vars)
        
        # Create random combinations - only use + and * which are in all operator sets
        choice = rand(rng, 1:4)
        expr = if choice <= 1
            x1 + x2
        elseif choice <= 2
            x1 * x2
        elseif choice <= 3
            x1 * x2 + c
        else
            x1 + x2 * x3
        end
        
        push!(expressions, expr)
    end
    
    return expressions
end

# Basic operators
basic_ops = OperatorEnum(; binary_operators=(+, -, *, /), unary_operators=(sin, cos))

for T in (Float32, Float64)
    for size in [5, 10, 20]
        exprs = gen_expressions(size * 20, basic_ops, T)  # More expressions for each "size"
        SUITE["basic"][T]["size_$(size)_order_1"] = @benchmarkable compute_derivatives($exprs, 1)
        SUITE["basic"][T]["size_$(size)_order_2"] = @benchmarkable compute_derivatives($exprs, 2)
    end
end

# Extended operators  
extended_ops = OperatorEnum(; 
    binary_operators=(+, -, *, /), 
    unary_operators=(sin, cos, sinh, cosh, exp, abs, -, inv)
)

for T in (Float32, Float64)
    exprs = gen_expressions(100, extended_ops, T)
    for order in 1:3
        SUITE["extended"][T]["order_$(order)"] = @benchmarkable compute_derivatives($exprs, $order)
    end
end

# Custom operators
my_op(x) = 2x + 1
my_binop(x, y) = x*x + y
@declare_expression_operator(my_op, 1)
@declare_expression_operator(my_binop, 2)

custom_ops = OperatorEnum(; binary_operators=(+, -, *, my_binop), unary_operators=(my_op, sin))

for T in (Float32, Float64)
    exprs = gen_expressions(100, custom_ops, T)
    SUITE["custom"][T]["order_1"] = @benchmarkable compute_derivatives($exprs, 1)
    SUITE["custom"][T]["order_2"] = @benchmarkable compute_derivatives($exprs, 2)
end