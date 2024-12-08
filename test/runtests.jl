using SafeTestsets
using TestItemRunner

if get(ENV, "DA_JET_TEST", "0") == "1"
    @safetestset "Code linting (JET.jl)" begin
        using Preferences
        set_preferences!("DynamicAutodiff", "instability_check" => "disable"; force=true)
        using JET
        using DynamicAutodiff
        JET.test_package(DynamicAutodiff; target_defined_modules=true)
    end
else
    @eval @run_package_tests verbose = true
end
@testitem "Code quality (Aqua.jl)" begin
    using DynamicAutodiff
    using Aqua
    Aqua.test_all(DynamicAutodiff)
end

@testitem "Test symbolic derivatives" begin
    using DynamicAutodiff: D
    using SymbolicRegression: ComposableExpression, Node
    using DynamicExpressions: OperatorEnum, @declare_expression_operator, AbstractExpression

    # Basic setup
    operators = OperatorEnum(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
    variable_names = ["x1", "x2"]
    x1 = ComposableExpression(Node(Float64; feature=1); operators, variable_names)
    x2 = ComposableExpression(Node(Float64; feature=2); operators, variable_names)

    # Test constant derivative
    c = ComposableExpression(Node(Float64; val=3.0); operators, variable_names)
    @test string(D(c, 1)) == "0.0"
    @test D(c, 1)([1.0]) ≈ [0.0]
    @test D(x1 + x2, 1)([0.0], [0.0]) ≈ [1.0]
    @test D(x1 + x2 * x2, 2)([0.0], [2.0]) ≈ [4.0]

    @test D(x1 * x2, 1)([1.0], [2.0]) ≈ [2.0]

    # Second order!
    @test D(D(x1 * x2, 1), 2)([1.0], [2.0]) ≈ [1.0]
    @test D(D(3.0 * x1 * x2 - x2, 1), 2)([1.0], [2.0]) ≈ [3.0]
    @test D(D(x1 * x2, 1), 1)([1.0], [2.0]) ≈ [0.0]

    # Unary operators:
    @test D(sin(x1), 1)([1.0]) ≈ [cos(1.0)]
    @test D(cos(x1), 1)([1.0]) ≈ [-sin(1.0)]
    @test D(sin(x1) * cos(x2), 1)([1.0], [2.0]) ≈ [cos(1.0) * cos(2.0)]
    @test D(D(sin(x1) * cos(x2), 1), 2)([1.0], [2.0]) ≈ [cos(1.0) * -sin(2.0)]

    # Also simplifies over `*`
    @test repr(D(x1 * x2, 1)) == "x2"

    # We also have special behavior when there is no dependence:
    @test repr(D(sin(x2), 1)) == "0.0"
    @test repr(D(x2 + sin(x2), 1)) == "0.0"
    @test repr(D(x2 + sin(x2) - x1, 1)) == "-1.0"

    # But still nice printing for things like -sin:
    @test repr(D(D(sin(x1), 1), 1)) == "-sin(x1)"

    # Without generating weird additional operators:
    @test repr(D(D(D(sin(x1), 1), 1), 1)) == "-cos(x1)"

    # Custom functions have nice printing:
    my_op(x) = sin(x)
    @declare_expression_operator(my_op, 1)
    my_bin_op(x, y) = x + y
    @declare_expression_operator(my_bin_op, 2)
    operators = OperatorEnum(;
        binary_operators=(+, -, *, /, my_bin_op), unary_operators=(my_op,)
    )

    x = ComposableExpression(Node(Float64; feature=1); operators, variable_names)
    y = ComposableExpression(Node(Float64; feature=2); operators, variable_names)

    @test repr(D(my_op(x), 1)) == "∂my_op(x1)"
    @test repr(D(D(my_op(x), 1), 1)) == "∂∂my_op(x1)"

    @test repr(D(my_bin_op(x, y), 1)) == "∂₁my_bin_op(x1, x2)"
    @test repr(D(my_bin_op(x, y), 2)) == "∂₂my_bin_op(x1, x2)"
    @test repr(D(my_bin_op(x, x - y), 2)) == "∂₂my_bin_op(x1, x1 - x2) * -1.0"

    operators = OperatorEnum(;
        binary_operators=(+, *, /, -),
        unary_operators=(sin, cos, sinh, cosh, abs, sign, -, inv),
    )
    x1, x2 = (
        ComposableExpression(Node(Float64; feature=i); operators, variable_names) for
        i in 1:2
    )
    # Test hyperbolic functions
    @test repr(D(sinh(x1), 1)) == "cosh(x1)"
    @test repr(D(cosh(x1), 1)) == "sinh(x1)"
    @test D(sinh(x2), 1)([1.0], [2.0]) ≈ [0.0]
    @test D(cosh(x2), 1)([1.0], [2.0]) ≈ [0.0]

    # Test absolute value and sign functions
    @test repr(D(abs(x1), 1)) == "sign(x1)"
    @test repr(D(D(abs(x1), 1), 1)) == "0.0"
    @test repr(D(sign(x1), 1)) == "0.0"
    @test D(abs(x1), 1)([-2.0]) ≈ [-1.0]
    @test D(D(abs(x1), 1), 1)([-2.0]) ≈ [0.0]
    @test D(abs(x1), 1)([2.0]) ≈ [1.0]

    # Test negation
    @test repr(D(-x1, 1)) == "-1.0"
    @test D(-x2, 1)([1.0], [2.0]) ≈ [0.0]

    # Test inverse
    @test repr(D(inv(x1), 1)) == "∂inv(x1)"
    @test repr(D(D(inv(x1), 1), 1)) == "∂∂inv(x1)"
    @test repr(D(D(D(inv(x1), 1), 1), 1)) == "∂∂∂inv(x1)"

    # Test division pretty printing
    @test repr(D(x1 / x2, 1)) == "∂₁[/](x1, x2)"
    @test repr(D(x1 / x2, 2)) == "∂₂[/](x1, x2)"
    @test repr(D(D(x1 / x2, 1), 2)) == "∂₁∂₂[/](x1, x2)"
    @test repr(D(D(D(x1 / x2, 1), 2), 2)) == "∂₁∂₂∂₂[/](x1, x2)"
    # Test different order gives same string:
    @test repr(D(D(D(x1 / x2, 2), 2), 1)) == "∂₁∂₂∂₂[/](x1, x2)"
    @test repr(D(D(D(D(x1 / x2, 2), 2), 1), 1)) == "0.0"

    @test D(x1 / x2, 1)([1.0], [2.0]) ≈ [0.5]
    @test D(x1 / x2, 2)([1.0], [2.0]) ≈ [-0.25]
    @test D(x1 / x2, 2)([2.0], [2.0]) ≈ [-0.5]
    @test D(D(x1 / x2, 1), 2)([1.0], [2.0]) ≈ [-0.25]

    # Test combinations
    @test repr(D(x1 * x2 + cos(x1), 1)) == "x2 + -sin(x1)"
    @test D(x1 * x2 + cos(x1), 1)([1.0], [2.0]) ≈ [2.0 - sin(1.0)]
    @test repr(D(x1 / (x2 + sin(x1)), 2)) == "∂₂[/](x1, x2 + sin(x1))"
    @test repr(D(x1 / (x2 * x2 + sin(x1)), 2)) ==
        "∂₂[/](x1, (x2 * x2) + sin(x1)) * (x2 + x2)"
    @test D(x1 / (x2 * x2 + sin(x1)), 2)([1.0], [2.0]) ≈
        [-1.0 / (2.0 * 2.0 + sin(1.0))^2 * (2.0 + 2.0)]
end

@testitem "Test for missing operator error" begin
    using DynamicAutodiff: D
    using SymbolicRegression: ComposableExpression, Node
    using DynamicExpressions: OperatorEnum, AbstractExpression

    # Basic setup
    operators = OperatorEnum(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
    variable_names = ["x1", "x2"]
    x1 = ComposableExpression(Node(Float64; feature=1); operators, variable_names)

    # Test for the error when 'sinh' is not in the operator set
    @test_throws "Operator sinh not found" repr(D(sinh(x1), 1))
end

@testitem "Test higher-order derivatives of inverse functions" begin
    using DynamicAutodiff: D
    using SymbolicRegression: ComposableExpression, Node
    using DynamicExpressions: OperatorEnum, AbstractExpression

    # Update operators to include 'inv'
    operators = OperatorEnum(;
        binary_operators=(+, *, /, -), unary_operators=(inv, sin, cos)
    )
    variable_names = ["x1", "x2"]
    x1 = ComposableExpression(Node(Float64; feature=1); operators, variable_names)

    @test repr(D(inv(x1), 1)) == "∂inv(x1)"
    @test D(inv(x1), 1)([2.0]) ≈ [-1.0 / 2.0^2]

    @test repr(D(D(inv(x1), 1), 1)) == "∂∂inv(x1)"
    @test D(D(inv(x1), 1), 1)([2.0]) ≈ [2.0 / 2.0^3]

    @test repr(D(D(D(inv(x1), 1), 1), 1)) == "∂∂∂inv(x1)"
    @test D(D(D(inv(x1), 1), 1), 1)([2.0]) ≈ [-6.0 / 2.0^4]
end

@testitem "Test simplification in derivatives" begin
    using DynamicAutodiff: D
    using SymbolicRegression: ComposableExpression, Node
    using DynamicExpressions: OperatorEnum, AbstractExpression

    # Operators with 'identity' and constants
    operators = OperatorEnum(;
        binary_operators=(+, *, /, -), unary_operators=(sin, cos, identity)
    )
    variable_names = ["x1"]
    x1 = ComposableExpression(Node(Float64; feature=1); operators, variable_names)

    # Derivative of constant times a variable
    c = ComposableExpression(Node(Float64; val=5.0); operators, variable_names)
    expr = c * x1
    @test repr(D(expr, 1)) == "5.0"

    # Derivative when expression has no dependence on the variable
    expr = sin(x1)
    @test repr(D(expr, 2)) == "0.0"
    @test D(expr, 2)([1.0]) ≈ [0.0]
end

@testitem "Test special functions and their derivatives" begin
    using DynamicAutodiff: D
    import DynamicAutodiff: _zero, _one, _n_one
    using SymbolicRegression: ComposableExpression, Node
    using DynamicExpressions: OperatorEnum, AbstractExpression, @declare_expression_operator

    @declare_expression_operator(_zero, 1)
    @declare_expression_operator(_one, 1)
    @declare_expression_operator(_n_one, 1)

    # Update operators to include special functions
    operators = OperatorEnum(;
        binary_operators=(+, *, /, -), unary_operators=(identity, _zero, _one, _n_one)
    )
    variable_names = ["x1", "x2"]
    x1 = ComposableExpression(Node{Float64}(; feature=1); operators, variable_names)
    x2 = ComposableExpression(Node{Float64}(; feature=2); operators, variable_names)

    # Test identity function
    @test repr(D(identity(x1), 1)) == "1.0"
    @test D(identity(x1), 1)([2.0], [3.0]) ≈ [1.0]

    # Test _zero function
    expr_zero = _zero(x1)
    @test repr(D(expr_zero, 1)) == "0.0"
    @test D(expr_zero, 1)([2.0], [3.0]) ≈ [0.0]

    # # Test _one function
    expr_one = _one(x1)
    @test repr(D(expr_one, 1)) == "0.0"
    @test D(expr_one, 1)([2.0], [3.0]) ≈ [0.0]
end

@testitem "Test custom operators" begin
    using DynamicExpressions: OperatorEnum, Expression, AbstractExpression
    using DynamicExpressions: Node, @declare_expression_operator, get_op_name
    using DynamicAutodiff: D

    my_op(x) = x
    my_bin_op(x, y) = x + y^2
    @declare_expression_operator(my_op, 1)
    @declare_expression_operator(my_bin_op, 2)
    operators = OperatorEnum(; unary_operators=(my_op,), binary_operators=(+, *, my_bin_op))
    x1, x2 = (
        Expression(Node{Float64}(; feature=i); operators, variable_names=["x1", "x2"]) for
        i in 1:2
    )
    ex1 = my_op(x1)
    @test repr(D(ex1, 1)) == "∂my_op(x1)"
    @test repr("text/plain", D(ex1, 1)) == "∂my_op(x1)"
    @test D(ex1, 1)([3.0;;]) ≈ [1.0]

    ex = my_bin_op(x1, x2)
    @test repr(D(ex, 1)) == "∂₁my_bin_op(x1, x2)"
    @test repr(D(ex, 2)) == "∂₂my_bin_op(x1, x2)"
    @test D(ex, 1)([3.0 4.0]') ≈ [1.0]
    @test D(ex, 2)([3.0 4.0]') ≈ [8.0]
end

@testitem "Missing coverage" begin
    # Due to Coverage.jl missing inlined functions, we test explicitly
    using DynamicAutodiff: D, _classify_operator, _zero, _one, _n_one, _first
    using DynamicAutodiff: _last, _n_sin, _n_cos, operator_derivative, DivMonomial
    using DynamicAutodiff: Zero, One, NegOne, First, Last, NonConstant
    using DynamicExpressions: get_op_name

    @test _zero(1.0) == 0.0
    @test _one(1.0) == 1.0
    @test _n_one(1.0) == -1.0
    @test _first(1.0, 2.0) == 1.0
    @test _last(1.0, 2.0) == 2.0

    @test operator_derivative(_zero, Val(1), Val(1)) == _zero
    @test operator_derivative(_zero, Val(2), Val(1)) == _zero
    @test operator_derivative(_zero, Val(2), Val(2)) == _zero
    @test operator_derivative(_one, Val(1), Val(1)) == _zero
    @test operator_derivative(_one, Val(2), Val(1)) == _zero
    @test operator_derivative(_one, Val(2), Val(2)) == _zero

    @test operator_derivative(sin, Val(1), Val(1)) == cos
    @test operator_derivative(cos, Val(1), Val(1)) == _n_sin
    @test operator_derivative(_n_sin, Val(1), Val(1)) == _n_cos
    @test operator_derivative(_n_cos, Val(1), Val(1)) == sin
    @test operator_derivative(exp, Val(1), Val(1)) == exp

    @test _n_sin(1.0) == -sin(1.0)
    @test _n_cos(1.0) == -cos(1.0)

    @test get_op_name(_n_sin) == "-sin"
    @test get_op_name(_n_cos) == "-cos"

    @test _classify_operator(_n_sin) == NonConstant
    @test _classify_operator(_n_cos) == NonConstant
    @test _classify_operator(_zero) == Zero
    @test _classify_operator(_one) == One
    @test _classify_operator(_n_one) == NegOne
    @test _classify_operator(_first) == First
    @test _classify_operator(_last) == Last

    @test operator_derivative(abs, Val(1), Val(1)) == sign
    @test operator_derivative(sign, Val(1), Val(1)) == _zero

    @test operator_derivative(identity, Val(1), Val(1)) == _one
    @test operator_derivative(-, Val(1), Val(1)) == _n_one

    @test operator_derivative(+, Val(2), Val(1)) == _one
    @test operator_derivative(+, Val(2), Val(2)) == _one
    @test operator_derivative(-, Val(2), Val(1)) == _one
    @test operator_derivative(-, Val(2), Val(2)) == _n_one

    @test operator_derivative(*, Val(2), Val(1)) == _last
    @test operator_derivative(*, Val(2), Val(2)) == _first

    @test operator_derivative(/, Val(2), Val(1)) == DivMonomial{1,0,1}()
    @test operator_derivative(operator_derivative(/, Val(2), Val(2)), Val(2), Val(2)) isa
        DivMonomial{2,1,3}
end
