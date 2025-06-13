using DynamicExpressions:
    AbstractExpression,
    AbstractExpressionNode,
    OperatorEnum,
    constructorof,
    DynamicExpressions as DE

const DE_2 = isdefined(DE, :max_degree)

"""
    D(ex::AbstractExpression, feature::Integer)

Compute the derivative of `ex` with respect to the `feature`-th variable.
Returns a new expression with an expanded set of operators.
"""
function D(ex::AbstractExpression, feature::Integer)
    metadata = DE.get_metadata(ex)
    raw_metadata = getfield(metadata, :_data)  # TODO: Upstream this so we can load this
    operators = DE.get_operators(ex)
    tree = DE.get_contents(ex)
    operators_with_derivatives = _make_derivative_operators(operators)
    ctx = _make_context(operators, operators_with_derivatives, feature)
    d_tree = _symbolic_derivative(tree, ctx)
    return DE.with_metadata(
        DE.with_contents(ex, d_tree); raw_metadata..., operators=operators_with_derivatives
    )
end

# Holds metadata about the derivative computation.
Base.@kwdef struct SymbolicDerivativeContext{NUM_OP,SIMPLIFIES_TO}
    feature::Int
    plus_idx::Int
    mult_idx::Int
    nops::NUM_OP
    simplifies_to::SIMPLIFIES_TO
end

function _get_ops_tuple(operators::OperatorEnum)
    if hasfield(OperatorEnum, :unaops)
        # Old API
        return (operators.unaops, operators.binops)
    else
        return operators.ops
    end
end

function _make_context(
    operators::OperatorEnum, operators_with_derivatives::OperatorEnum, feature::Integer
)
    all_ops = _get_ops_tuple(operators)
    all_ops_with_derivatives = _get_ops_tuple(operators_with_derivatives)
    if length(all_ops) < 2 || !_has_operator(*, all_ops[2]) || !_has_operator(+, all_ops[2])
        throw(
            ArgumentError(
                "Binary `*` or `+` operator missing from operators, so differentiation is not possible.",
            ),
        )
    end
    nops = map(length, all_ops)
    mult_idx = _get_index(*, all_ops[2])
    plus_idx = _get_index(+, all_ops[2])
    simplifies_to = map(_classify_all_operators, all_ops_with_derivatives)
    return SymbolicDerivativeContext(; feature, plus_idx, mult_idx, nops, simplifies_to)
end

# These functions ensure compiler inference of the types, even for large tuples
@generated function _classify_all_operators(ops::Tuple{Vararg{Any,N}}) where {N}
    return :(Base.Cartesian.@ntuple($N, i -> _classify_operator(ops[i])))
end
@generated function _has_operator(op::F, ops::Tuple{Vararg{Any,N}}) where {F,N}
    return :(Base.Cartesian.@nany($N, i -> ops[i] == op))
end
@generated function _get_index(op::F, ops::Tuple{Vararg{Any,N}}) where {F,N}
    return :(Base.Cartesian.@nif($N, i -> ops[i] == op, i -> i))
end

function max_degree(::Type{E}) where {E<:AbstractExpression}
    return DE_2 ? DE.max_degree(E) : 2
end

function deg1_derivative(
    tree::N, ctx::SymbolicDerivativeContext
) where {T,N<:AbstractExpressionNode{T}}
    # f(g(x)) => f'(g(x)) * g'(x)
    f_prime_op = tree.op + ctx.nops[1]
    f_prime_simplifies_to = ctx.simplifies_to[1][f_prime_op]

    ### We do some simplification based on zero/one derivatives ###
    if f_prime_simplifies_to == Zero
        # 0 * g' => 0
        return constructorof(N)(; val=zero(T))
    else
        g_prime = _symbolic_derivative(tree.l, ctx)
        if g_prime.degree == 0 && g_prime.constant && iszero(g_prime.val)
            # f' * 0 => 0
            return g_prime
        else
            f_prime = if f_prime_simplifies_to == NegOne
                constructorof(N)(; val=-one(T))
            else
                constructorof(N)(; op=f_prime_op, l=tree.l)
            end

            if f_prime_simplifies_to == One
                # 1 * g' => g'
                return g_prime
            elseif g_prime.degree == 0 && g_prime.constant && isone(g_prime.val)
                # f' * 1 => f'
                return f_prime
            else
                return constructorof(N)(; op=ctx.mult_idx, l=f_prime, r=g_prime)
            end
        end
    end
end

function deg2_derivative(
    tree::N, ctx::SymbolicDerivativeContext
) where {T,N<:AbstractExpressionNode{T}}

    # f(g(x), h(x)) => f^(1,0)(g(x), h(x)) * g'(x) + f^(0,1)(g(x), h(x)) * h'(x)
    f_prime_left_op = tree.op + ctx.nops[2]
    f_prime_right_op = tree.op + 2 * ctx.nops[2]
    f_prime_left_simplifies_to = ctx.simplifies_to[2][f_prime_left_op]
    f_prime_right_simplifies_to = ctx.simplifies_to[2][f_prime_right_op]

    ### We do some simplification based on zero/one derivatives ###
    first_term = if f_prime_left_simplifies_to == Zero
        # 0 * g' => 0
        constructorof(N)(; val=zero(T))
    else
        g_prime = _symbolic_derivative(tree.l, ctx)

        if f_prime_left_simplifies_to == One
            # 1 * g' => g'
            g_prime
        elseif g_prime.degree == 0 && g_prime.constant && iszero(g_prime.val)
            # f' * 0 => 0
            g_prime
        else
            f_prime_left = if f_prime_left_simplifies_to == NegOne
                constructorof(N)(; val=-one(T))
            elseif f_prime_left_simplifies_to == First
                tree.l
            elseif f_prime_left_simplifies_to == Last
                tree.r
            else
                constructorof(N)(; op=f_prime_left_op, l=tree.l, r=tree.r)
            end

            if g_prime.degree == 0 && g_prime.constant && isone(g_prime.val)
                # f' * 1 => f'
                f_prime_left
            else
                # f' * g'
                constructorof(N)(; op=ctx.mult_idx, l=f_prime_left, r=g_prime)
            end
        end
    end

    second_term = if f_prime_right_simplifies_to == Zero
        # Simplify and just give zero
        constructorof(N)(; val=zero(T))
    else
        h_prime = _symbolic_derivative(tree.r, ctx)
        if f_prime_right_simplifies_to == One
            h_prime
        elseif h_prime.degree == 0 && h_prime.constant && iszero(h_prime.val)
            h_prime
        else
            f_prime_right = if f_prime_right_simplifies_to == NegOne
                constructorof(N)(; val=-one(T))
            elseif f_prime_right_simplifies_to == First
                tree.l
            elseif f_prime_right_simplifies_to == Last
                tree.r
            else
                constructorof(N)(; op=f_prime_right_op, l=tree.l, r=tree.r)
            end
            if h_prime.degree == 0 && h_prime.constant && isone(h_prime.val)
                f_prime_right
            else
                constructorof(N)(; op=ctx.mult_idx, l=f_prime_right, r=h_prime)
            end
        end
    end

    # Simplify if either term is zero
    if first_term.degree == 0 && first_term.constant && iszero(first_term.val)
        return second_term
    elseif second_term.degree == 0 && second_term.constant && iszero(second_term.val)
        return first_term
    else
        return constructorof(N)(; op=ctx.plus_idx, l=first_term, r=second_term)
    end
end

function _symbolic_derivative(
    tree::N, ctx::SymbolicDerivativeContext
) where {T,N<:AbstractExpressionNode{T}}
    # NOTE: We cannot mutate the tree here! Since we use it twice.

    # Quick test to see if we have any dependence on the feature, so
    # we can return 0 for the branch
    any_dependence = any(tree) do node
        node.degree == 0 && !node.constant && node.feature == ctx.feature
    end

    if !any_dependence
        return constructorof(N)(; val=zero(T))
    elseif tree.degree == 0 # && any_dependence
        return constructorof(N)(; val=one(T))
    elseif tree.degree == 1
        return deg1_derivative(tree, ctx)
    else  # tree.degree == 2
        return deg2_derivative(tree, ctx)
    end
end

function _make_derivative_operators(operators::OperatorEnum)
    all_ops = _get_ops_tuple(operators)
    return _make_operator_enum(
        ntuple(i -> _make_derivative_operators(all_ops[i], Val(i)), Val(length(all_ops)))
    )
    # TODO: I don't think these `Val(i)` are type stable
end

function _make_operator_enum(ops)
    if DE_2 === Val(true)
        return OperatorEnum(ops)
    else
        @assert length(ops) == 2
        unaops, binops = ops
        return OperatorEnum(binops, unaops)  # Compat with old constructor
    end
end

@generated function _make_derivative_operators(
    operator_tuple::Tuple{Vararg{Any,nops}}, ::Val{degree}
) where {nops,degree}
    quote
        # Essentially what this does is
        #
        # 1. For unary operators:
        #      (foo, bar) -> (foo, bar, ∂foo, ∂bar)
        # 2. For binary operators:
        #      (foo, bar) -> (foo, bar, ∂₁foo, ∂₁bar, ∂₂foo, ∂₂bar)
        #
        # and so on, for any degree and any number of operators.
        #
        # The `@ntuple` and `@nif` calls are used to make this generic to any
        # degree and any number of operators.

        return Base.Cartesian.@ntuple(
            $((degree + 1) * nops),
            new_op_index -> Base.Cartesian.@nif(
                $(degree + 1),
                arg_index_plus_1 -> new_op_index <= arg_index_plus_1 * $nops,
                arg_index_plus_1 -> let
                    if arg_index_plus_1 == 1
                        # (This is the `[foo, bar]` branch discussed above)
                        operator_tuple[new_op_index]
                    else
                        # This is the `[∂₁foo, ∂₁bar]` branch. Note that `arg_index_plus_1`
                        # is essentially used as the subscript for the derivative (plus 1)
                        # So literally `∂₁foo` would be `arg_index_plus_1 == 2`, and
                        # `operator_tuple[new_op_index - (arg_index_plus_1 - 1) * $nops] == foo`
                        operator_derivative(
                            operator_tuple[new_op_index - (arg_index_plus_1 - 1) * $nops],
                            Val($degree),
                            Val(arg_index_plus_1 - 1),
                        )
                    end
                end
            )
        )
    end
end
