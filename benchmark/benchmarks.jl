using BenchmarkTools
using DynamicDiff: D
using DynamicExpressions:
    Expression, OperatorEnum, @declare_expression_operator, AbstractExpression, Node
using Random

module TreeGenUtils

using DynamicExpressions:
    AbstractExpressionNode,
    AbstractNode,
    Node,
    NodeSampler,
    constructorof,
    set_node!,
    count_nodes
using Random: AbstractRNG, default_rng

"""
    random_node(tree::AbstractNode; filter::F=Returns(true))

Return a random node from the tree. You may optionally
filter the nodes matching some condition before sampling.
"""
function random_node(
    tree::AbstractNode, rng::AbstractRNG=default_rng(); filter::F=Returns(true)
) where {F<:Function}
    Base.depwarn(
        "Instead of `random_node(tree, filter)`, use `rand(NodeSampler(; tree, filter))`",
        :random_node,
    )
    return rand(rng, NodeSampler(; tree, filter))
end

function make_random_leaf(
    nfeatures::Int, ::Type{T}, ::Type{N}, rng::AbstractRNG=default_rng()
) where {T,N<:AbstractExpressionNode}
    if rand(rng, Bool)
        return constructorof(N)(; val=randn(rng, T))
    else
        return constructorof(N)(T; feature=rand(rng, 1:nfeatures))
    end
end

"""Add a random unary/binary operation to the end of a tree"""
function append_random_op(
    tree::AbstractExpressionNode{T},
    operators,
    nfeatures::Int,
    rng::AbstractRNG=default_rng();
    makeNewBinOp::Union{Bool,Nothing}=nothing,
) where {T}
    node = rand(rng, NodeSampler(; tree, filter=t -> t.degree == 0))
    nuna = length(operators.unaops)
    nbin = length(operators.binops)

    if makeNewBinOp === nothing
        choice = rand(rng)
        makeNewBinOp = choice < nbin / (nuna + nbin)
    end

    if makeNewBinOp
        newnode = constructorof(typeof(tree))(
            rand(rng, 1:nbin),
            make_random_leaf(nfeatures, T, typeof(tree), rng),
            make_random_leaf(nfeatures, T, typeof(tree), rng),
        )
    else
        newnode = constructorof(typeof(tree))(
            rand(rng, 1:nuna), make_random_leaf(nfeatures, T, typeof(tree), rng)
        )
    end

    set_node!(node, newnode)

    return tree
end

function gen_random_tree_fixed_size(
    node_count::Int,
    operators,
    nfeatures::Int,
    ::Type{T},
    node_type=Node,
    rng::AbstractRNG=default_rng(),
) where {T}
    tree = make_random_leaf(nfeatures, T, node_type, rng)
    cur_size = count_nodes(tree)
    while cur_size < node_count
        if cur_size == node_count - 1  # only unary operator allowed.
            length(operators.unaops) == 0 && break # We will go over the requested amount, so we must break.
            tree = append_random_op(tree, operators, nfeatures, rng; makeNewBinOp=false)
        else
            tree = append_random_op(tree, operators, nfeatures, rng)
        end
        cur_size = count_nodes(tree)
    end
    return tree
end

end  # module TreeGenUtils

using .TreeGenUtils: gen_random_tree_fixed_size

const SUITE = BenchmarkGroup()

# Simple random expression generator that adapts to available operators
function gen_expressions(seed, operators::OperatorEnum; num_expressions=512, maxsize=20)
    rng = MersenneTwister(seed)
    vars = ["x1", "x2", "x3"]

    expressions = []
    for _ in 1:num_expressions
        # Create random combinations - only use + and * which are in all operator sets
        size = rand(rng, 1:maxsize)
        tree = gen_random_tree_fixed_size(size, operators, 3, Float64, Node, rng)
        expr = Expression(tree; operators, variable_names=vars)
        push!(expressions, expr)
    end

    return expressions
end

compute_derivatives(exprs, ::Val{1}) = [D(expr, 1) for expr in exprs]
compute_derivatives(exprs, ::Val{2}) = [D(D(expr, 1), 1) for expr in exprs]
compute_derivatives(exprs, ::Val{3}) = [D(D(D(expr, 1), 1), 1) for expr in exprs]

# Basic operators
basic_ops = OperatorEnum(; binary_operators=(+, -, *, /), unary_operators=(sin, cos))

for order in 1:3
    SUITE["basic"]["size_$(size)_order_$(order)"] = @benchmarkable(
        compute_derivatives(exprs, $(Val(order))),
        setup = (exprs = gen_expressions(0, basic_ops)),
    )
end

# Extended operators  
extended_ops = OperatorEnum(;
    binary_operators=(+, -, *, /), unary_operators=(sin, cos, sinh, cosh, exp, abs, inv)
)

for order in 1:3
    SUITE["extended"]["order_$(order)"] = @benchmarkable(
        compute_derivatives(exprs, $(Val(order))),
        setup = (exprs = gen_expressions(0, extended_ops)),
    )
end

# Custom operators
my_op(x) = 2x + 1
my_binop(x, y) = x * x + y
@declare_expression_operator(my_op, 1)
@declare_expression_operator(my_binop, 2)

custom_ops = OperatorEnum(;
    binary_operators=(+, -, *, my_binop), unary_operators=(my_op, sin)
)

for order in 1:3
    SUITE["custom"]["order_$(order)"] = @benchmarkable(
        compute_derivatives(exprs, $(Val(order))),
        setup = (exprs = gen_expressions(0, custom_ops)),
    )
end
