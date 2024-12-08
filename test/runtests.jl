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
end

## TODO: Add this back in once SR modifies `D`.
# @testitem "Test template structure with derivatives" begin
#     using DynamicAutodiff: D
#     using SymbolicRegression:
#         ComposableExpression, Node, TemplateStructure, TemplateExpression
#     using DynamicExpressions: OperatorEnum

#     # Basic setup
#     operators = OperatorEnum(; binary_operators=(+, *, /, -), unary_operators=(sin, cos))
#     variable_names = ["x1", "x2"]
#     x1 = ComposableExpression(Node(Float64; feature=1); operators, variable_names)
#     x2 = ComposableExpression(Node(Float64; feature=2); operators, variable_names)

#     # Create a structure that computes f(x1, x2) and its derivative with respect to x1
#     structure = TemplateStructure{(:f,)}(((; f), (x1, x2)) -> f(x1, x2) + D(f, 1)(x1, x2))
#     # We pass the functions through:
#     @test structure.num_features == (; f=2)

#     # Test with a simple function and its derivative
#     expr = TemplateExpression((; f=x1 * sin(x2)); structure, operators, variable_names)

#     # Truth: x1 * sin(x2) + sin(x2)
#     X = randn(2, 32)
#     @test expr(X) ≈ X[1, :] .* sin.(X[2, :]) .+ sin.(X[2, :])
# end
