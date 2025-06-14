using BenchmarkTools
using DynamicDiff: D
using DynamicExpressions: OperatorEnum, @declare_expression_operator, AbstractExpression
using SymbolicRegression: ComposableExpression, Node
using Random

const SUITE = BenchmarkGroup()

# Utility function to generate random expressions of fixed size
function gen_random_expression(size::Int, operators::OperatorEnum, n_features::Int, ::Type{T}, rng::AbstractRNG=Random.default_rng()) where {T}
    variable_names = ["x$i" for i in 1:n_features]
    
    # Create a random tree structure
    if size == 1
        if rand(rng) < 0.5
            # Create a variable
            return ComposableExpression(Node(T; feature=rand(rng, 1:n_features)); operators, variable_names)
        else
            # Create a constant
            return ComposableExpression(Node(T; val=randn(rng, T)); operators, variable_names)
        end
    end
    
    # Get operator tuples - handle different API versions
    ops_tuple = if hasfield(typeof(operators), :ops)
        operators.ops
    else
        (operators.unaops, operators.binops)
    end
    
    # Determine if this should be a unary or binary operation
    use_unary = size > 1 && rand(rng) < 0.3 && length(ops_tuple[1]) > 0
    
    if use_unary
        op = rand(rng, ops_tuple[1])
        child = gen_random_expression(size - 1, operators, n_features, T, rng)
        return op(child)
    else
        # Binary operation
        if length(ops_tuple[2]) == 0
            # Fall back to variable if no binary ops
            return ComposableExpression(Node(T; feature=rand(rng, 1:n_features)); operators, variable_names)
        end
        
        op = rand(rng, ops_tuple[2])
        left_size = max(1, div(size - 1, 2))
        right_size = size - 1 - left_size
        
        left = gen_random_expression(left_size, operators, n_features, T, rng)
        right = gen_random_expression(right_size, operators, n_features, T, rng)
        
        return op(left, right)
    end
end

# Benchmark first-order derivatives
function benchmark_first_order_derivatives()
    suite = BenchmarkGroup()
    
    # Basic operators
    operators = OperatorEnum(;
        binary_operators=(+, -, *, /), 
        unary_operators=(sin, cos, exp, log)
    )
    
    variable_names = ["x1", "x2", "x3"]
    
    for T in (Float32, Float64)
        suite[T] = BenchmarkGroup()
        
        # Simple expressions
        x1 = ComposableExpression(Node(T; feature=1); operators, variable_names)
        x2 = ComposableExpression(Node(T; feature=2); operators, variable_names)
        x3 = ComposableExpression(Node(T; feature=3); operators, variable_names)
        
        simple_exprs = [
            x1 + x2,
            x1 * x2,
            x1 / x2,
            sin(x1),
            cos(x1) * x2,
            x1 * x1 + x2 * x2,  # Use x*x instead of x^2
            exp(x1) - log(x2)
        ]
        
        # Filter out expressions that might not work due to operator limitations
        valid_exprs = []
        for expr in simple_exprs
            try
                D(expr, 1)  # Test if derivative can be computed
                push!(valid_exprs, expr)
            catch
                # Skip expressions that can't be differentiated
            end
        end
        
        if !isempty(valid_exprs)
            suite[T]["simple"] = @benchmarkable(
                [D(expr, 1) for expr in exprs],
                setup=(exprs = $valid_exprs)
            )
        end
        
        # Complex expressions of different sizes
        for size in [5, 10, 20]
            suite[T]["size_$(size)"] = @benchmarkable(
                [D(expr, rand(1:3)) for expr in exprs],
                setup=(
                    rng = MersenneTwister(42);
                    exprs = [gen_random_expression($size, $operators, 3, $T, rng) for _ in 1:50]
                )
            )
        end
    end
    
    return suite
end

# Benchmark higher-order derivatives
function benchmark_higher_order_derivatives()
    suite = BenchmarkGroup()
    
    operators = OperatorEnum(;
        binary_operators=(+, -, *, /), 
        unary_operators=(sin, cos)
    )
    
    variable_names = ["x1", "x2"]
    
    for T in (Float32, Float64)
        suite[T] = BenchmarkGroup()
        
        x1 = ComposableExpression(Node(T; feature=1); operators, variable_names)
        x2 = ComposableExpression(Node(T; feature=2); operators, variable_names)
        
        # Test expressions for higher-order derivatives
        base_exprs = [
            x1 * x2,
            sin(x1) * cos(x2),
            x1 + x2 * x1
        ]
        
        # Second-order derivatives
        suite[T]["second_order"] = @benchmarkable(
            [D(D(expr, 1), 2) for expr in exprs],
            setup=(exprs = $base_exprs)
        )
        
        # Third-order derivatives
        suite[T]["third_order"] = @benchmarkable(
            [D(D(D(expr, 1), 1), 2) for expr in exprs],
            setup=(exprs = $base_exprs)
        )
        
        # Mixed derivatives
        suite[T]["mixed_derivatives"] = @benchmarkable(
            [D(D(expr, 1), 2) for expr in exprs],
            setup=(exprs = $base_exprs)
        )
    end
    
    return suite
end

# Benchmark different operator types
function benchmark_operators()
    suite = BenchmarkGroup()
    
    for T in (Float32, Float64)
        suite[T] = BenchmarkGroup()
        
        # Trigonometric functions
        trig_operators = OperatorEnum(;
            binary_operators=(+, -, *), 
            unary_operators=(sin, cos)
        )
        
        variable_names = ["x"]
        x = ComposableExpression(Node(T; feature=1); trig_operators, variable_names)
        
        trig_exprs = [sin(x), cos(x), sin(x) * cos(x)]
        
        suite[T]["trigonometric"] = @benchmarkable(
            [D(expr, 1) for expr in exprs],
            setup=(exprs = $trig_exprs)
        )
        
        # Hyperbolic functions
        hyp_operators = OperatorEnum(;
            binary_operators=(+, -, *), 
            unary_operators=(sinh, cosh)
        )
        
        x_hyp = ComposableExpression(Node(T; feature=1); hyp_operators, variable_names)
        hyp_exprs = [sinh(x_hyp), cosh(x_hyp), sinh(x_hyp) + cosh(x_hyp)]
        
        suite[T]["hyperbolic"] = @benchmarkable(
            [D(expr, 1) for expr in exprs],
            setup=(exprs = $hyp_exprs)
        )
        
        # Special functions
        special_operators = OperatorEnum(;
            binary_operators=(+, -, *, /), 
            unary_operators=(abs, sign, -, inv)
        )
        
        x_special = ComposableExpression(Node(T; feature=1); special_operators, variable_names)
        special_exprs = [abs(x_special), -x_special, inv(x_special)]
        
        suite[T]["special"] = @benchmarkable(
            [D(expr, 1) for expr in exprs],
            setup=(exprs = $special_exprs)
        )
    end
    
    return suite
end

# Benchmark evaluation of derivatives
function benchmark_derivative_evaluation()
    suite = BenchmarkGroup()
    
    operators = OperatorEnum(;
        binary_operators=(+, -, *, /), 
        unary_operators=(sin, cos, exp)
    )
    
    variable_names = ["x1", "x2"]
    
    for T in (Float32, Float64)
        suite[T] = BenchmarkGroup()
        
        x1 = ComposableExpression(Node(T; feature=1); operators, variable_names)
        x2 = ComposableExpression(Node(T; feature=2); operators, variable_names)
        
        # Create derivative expressions
        expr = sin(x1) * x2 + cos(x1)
        d_expr = D(expr, 1)
        
        # Benchmark evaluation of the derivative
        suite[T]["evaluation"] = @benchmarkable(
            d_expr(X),
            setup=(X = randn($T, 2, 1000))
        )
        
        # Benchmark both derivative computation and evaluation
        suite[T]["compute_and_evaluate"] = @benchmarkable(
            D(expr, 1)(X),
            setup=(
                expr = $expr;
                X = randn($T, 2, 1000)
            )
        )
    end
    
    return suite
end

# Benchmark custom operators
function benchmark_custom_operators()
    suite = BenchmarkGroup()
    
    # Define custom operators
    my_unary(x) = 2 * x
    my_binary(x, y) = x * x + y * y  # Use x*x instead of x^2
    
    @declare_expression_operator(my_unary, 1)
    @declare_expression_operator(my_binary, 2)
    
    custom_operators = OperatorEnum(;
        binary_operators=(+, -, *, my_binary), 
        unary_operators=(my_unary, sin, cos)
    )
    
    variable_names = ["x1", "x2"]
    
    for T in (Float32, Float64)
        suite[T] = BenchmarkGroup()
        
        x1 = ComposableExpression(Node(T; feature=1); custom_operators, variable_names)
        x2 = ComposableExpression(Node(T; feature=2); custom_operators, variable_names)
        
        custom_exprs = [
            my_unary(x1),
            my_binary(x1, x2),
            my_unary(x1) + my_binary(x1, x2)
        ]
        
        suite[T]["custom"] = @benchmarkable(
            [D(expr, 1) for expr in exprs],
            setup=(exprs = $custom_exprs)
        )
    end
    
    return suite
end

# Build the complete benchmark suite
SUITE["first_order"] = benchmark_first_order_derivatives()
SUITE["higher_order"] = benchmark_higher_order_derivatives()
SUITE["operators"] = benchmark_operators()
SUITE["evaluation"] = benchmark_derivative_evaluation()
SUITE["custom"] = benchmark_custom_operators()