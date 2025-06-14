using BenchmarkTools
using DynamicDiff: D
using DynamicExpressions: OperatorEnum, @declare_expression_operator
using SymbolicRegression: ComposableExpression, Node
using Random

const SUITE = BenchmarkGroup()

# Helper functions to avoid list comprehensions in benchmarks
compute_first_derivatives(exprs, var) = [D(expr, var) for expr in exprs]
compute_second_derivatives(exprs, var1, var2) = [D(D(expr, var1), var2) for expr in exprs]
compute_third_derivatives(exprs, var1, var2, var3) = [D(D(D(expr, var1), var2), var3) for expr in exprs]

# Generate random expressions
function gen_random_expressions(n_exprs::Int, size::Int, operators::OperatorEnum, n_features::Int, ::Type{T}) where {T}
    rng = MersenneTwister(42)  # Fixed seed for reproducibility
    variable_names = ["x$i" for i in 1:n_features]
    
    expressions = []
    
    for _ in 1:n_exprs
        expr = gen_single_expression(size, operators, n_features, T, variable_names, rng)
        push!(expressions, expr)
    end
    
    return expressions
end

function gen_single_expression(size::Int, operators::OperatorEnum, n_features::Int, ::Type{T}, variable_names, rng) where {T}
    if size == 1
        if rand(rng) < 0.7  # Favor variables over constants
            return ComposableExpression(Node(T; feature=rand(rng, 1:n_features)); operators, variable_names)
        else
            return ComposableExpression(Node(T; val=randn(rng, T)); operators, variable_names)
        end
    end
    
    # Get operators - handle API differences
    ops_tuple = if hasfield(typeof(operators), :ops)
        operators.ops
    else
        (operators.unaops, operators.binops)
    end
    
    # Choose unary vs binary
    if length(ops_tuple[1]) > 0 && rand(rng) < 0.3
        # Unary operation
        op = rand(rng, ops_tuple[1])
        child = gen_single_expression(size - 1, operators, n_features, T, variable_names, rng)
        return op(child)
    else
        # Binary operation
        if length(ops_tuple[2]) == 0
            return ComposableExpression(Node(T; feature=rand(rng, 1:n_features)); operators, variable_names)
        end
        
        op = rand(rng, ops_tuple[2])
        left_size = max(1, rand(rng, 1:(size-1)))
        right_size = size - 1 - left_size
        
        left = gen_single_expression(left_size, operators, n_features, T, variable_names, rng)
        right = gen_single_expression(right_size, operators, n_features, T, variable_names, rng)
        
        return op(left, right)
    end
end

# Basic operator set
function benchmark_basic_operators()
    suite = BenchmarkGroup()
    
    operators = OperatorEnum(; binary_operators=(+, -, *, /), unary_operators=(sin, cos))
    
    for T in (Float32, Float64)
        suite[T] = BenchmarkGroup()
        
        # Different expression sizes
        for size in [5, 10, 20]
            exprs = gen_random_expressions(100, size, operators, 3, T)
            
            suite[T]["first_order_size_$(size)"] = @benchmarkable(
                compute_first_derivatives(exprs, 1),
                setup=(exprs = $exprs)
            )
            
            suite[T]["second_order_size_$(size)"] = @benchmarkable(
                compute_second_derivatives(exprs, 1, 2),
                setup=(exprs = $exprs)
            )
        end
    end
    
    return suite
end

# Extended operator set
function benchmark_extended_operators()
    suite = BenchmarkGroup()
    
    operators = OperatorEnum(; 
        binary_operators=(+, -, *, /), 
        unary_operators=(sin, cos, sinh, cosh, exp, log, abs, -, inv)
    )
    
    for T in (Float32, Float64)
        suite[T] = BenchmarkGroup()
        
        exprs = gen_random_expressions(100, 15, operators, 3, T)
        
        suite[T]["first_order"] = @benchmarkable(
            compute_first_derivatives(exprs, 1),
            setup=(exprs = $exprs)
        )
        
        suite[T]["second_order"] = @benchmarkable(
            compute_second_derivatives(exprs, 1, 2),
            setup=(exprs = $exprs)
        )
        
        suite[T]["third_order"] = @benchmarkable(
            compute_third_derivatives(exprs, 1, 2, 1),
            setup=(exprs = $exprs)
        )
    end
    
    return suite
end

# Custom operators
function benchmark_custom_operators()
    suite = BenchmarkGroup()
    
    # Define custom operators
    my_op(x) = 2 * x + 1
    my_binop(x, y) = x * x + y
    
    @declare_expression_operator(my_op, 1)
    @declare_expression_operator(my_binop, 2)
    
    operators = OperatorEnum(; 
        binary_operators=(+, -, *, my_binop), 
        unary_operators=(my_op, sin, cos)
    )
    
    for T in (Float32, Float64)
        suite[T] = BenchmarkGroup()
        
        exprs = gen_random_expressions(100, 10, operators, 2, T)
        
        suite[T]["first_order"] = @benchmarkable(
            compute_first_derivatives(exprs, 1),
            setup=(exprs = $exprs)
        )
        
        suite[T]["second_order"] = @benchmarkable(
            compute_second_derivatives(exprs, 1, 2),
            setup=(exprs = $exprs)
        )
    end
    
    return suite
end

# Build the benchmark suite
SUITE["basic"] = benchmark_basic_operators()
SUITE["extended"] = benchmark_extended_operators()
SUITE["custom"] = benchmark_custom_operators()