using DynamicExpressions:
    AbstractExpression,
    AbstractExpressionNode,
    OperatorEnum,
    constructorof,
    get_child,
    get_children,
    DynamicExpressions as DE
using DispatchDoctor: @unstable

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

function _make_context(
    operators::OperatorEnum, operators_with_derivatives::OperatorEnum, feature::Integer
)
    if length(operators) < 2 ||
        !_has_operator(*, operators[2]) ||
        !_has_operator(+, operators[2])
        throw(
            ArgumentError(
                "Binary `*` or `+` operator missing from operators, so differentiation is not possible.",
            ),
        )
    end
    nops = map(length, operators.ops)
    mult_idx = _get_index(*, operators[2])
    plus_idx = _get_index(+, operators[2])
    simplifies_to = map(_classify_all_operators, operators_with_derivatives.ops)
    return SymbolicDerivativeContext(; feature, plus_idx, mult_idx, nops, simplifies_to)
end

tuple_length(::Type{<:Tuple{Vararg{Any,N}}}) where {N} = N::Int

# These functions ensure compiler inference of the types, even for large tuples
@generated function _classify_all_operators(ops::Tuple)
    quote
        Base.Cartesian.@ntuple($(tuple_length(ops)), i -> _classify_operator(ops[i]))  # COV_EXCL_LINE
    end
end
@generated function _has_operator(op::F, ops::Tuple) where {F}
    quote
        Base.Cartesian.@nany($(tuple_length(ops)), i -> ops[i] == op)  # COV_EXCL_LINE
    end
end
@generated function _get_index(op::F, ops::Tuple) where {F}
    quote
        Base.Cartesian.@nif($(tuple_length(ops)), i -> ops[i] == op, i -> i)  # COV_EXCL_LINE
    end
end

@generated function degn_derivative(
    tree::N, ctx::SymbolicDerivativeContext, ::Val{degree}
) where {T,N<:AbstractExpressionNode{T},degree}
    quote
        # df/dx => ∑ᵢ (∂ᵢf)(args...) * dargs[i]/dx
        f_prime_op = Base.Cartesian.@ntuple($degree, i -> tree.op + i * ctx.nops[$degree])
        f_prime_simplifies_to = Base.Cartesian.@ntuple(
            $degree, i -> ctx.simplifies_to[$degree][f_prime_op[i]]
        )

        ### We do some simplification based on zero/one derivatives ###
        terms = Base.Cartesian.@ntuple(
            $degree,
            i -> let
                if f_prime_simplifies_to[i] == Zero
                    # 0 * g' => 0
                    constructorof(N)(; val=zero(T))
                else
                    g_prime = _symbolic_derivative(get_child(tree, i), ctx)::N
                    if f_prime_simplifies_to[i] == One
                        # 1 * g' => g'
                        g_prime
                    elseif g_prime.degree == 0 && g_prime.constant && iszero(g_prime.val)
                        # f' * 0 => 0
                        g_prime
                    else
                        f_prime = if f_prime_simplifies_to[i] == NegOne
                            constructorof(N)(; val=-one(T))
                        elseif f_prime_simplifies_to[i] == First
                            get_child(tree, 1)
                        elseif f_prime_simplifies_to[i] == Last
                            get_child(tree, $degree)
                        else
                            constructorof(N)(;
                                op=f_prime_op[i],
                                children=get_children(tree, Val($degree)),
                            )
                        end

                        if g_prime.degree == 0 && g_prime.constant && isone(g_prime.val)
                            # f' * 1 => f'
                            f_prime
                        else
                            # f' * g'
                            constructorof(N)(; op=ctx.mult_idx, children=(f_prime, g_prime))
                        end
                    end
                end
            end
        )

        # Simplify if either term is zero
        if length(terms) == 2
            first_term = first(terms)
            second_term = last(terms)
            if first_term.degree == 0 && first_term.constant && iszero(first_term.val)
                return second_term
            elseif second_term.degree == 0 &&
                second_term.constant &&
                iszero(second_term.val)
                return first_term
            end
        end
        # Need to stitch together the terms with the plus operator
        if length(terms) == 1
            return only(terms)
        end
        return stitch_terms(terms, ctx)
    end
end

function stitch_terms(
    terms::Tuple{N,Vararg{N}}, ctx::SymbolicDerivativeContext
) where {N<:AbstractExpressionNode}
    return foldl((l, r) -> constructorof(N)(; op=ctx.plus_idx, children=(l, r)), terms)
end

function _any_dependence(tree::AbstractExpressionNode, feature::Integer)
    any(tree) do node
        node.degree == 0 && !node.constant && node.feature == feature
    end
end

@generated function _symbolic_derivative(
    tree::N, ctx::SymbolicDerivativeContext
) where {T,D,N<:AbstractExpressionNode{T,D}}
    quote
        # NOTE: We cannot mutate the tree here!

        # Quick test to see if we have any dependence on the feature, so
        # we can return 0 for the branch
        any_dependence = _any_dependence(tree, ctx.feature)

        deg = tree.degree
        out = if !any_dependence
            constructorof(N)(; val=zero(T))
        else
            if deg == 0
                constructorof(N)(; val=one(T))
            else
                Base.Cartesian.@nif(  # COV_EXCL_LINE
                    $D,
                    i -> i == deg,  # COV_EXCL_LINE
                    i -> begin  # COV_EXCL_LINE
                        degn_derivative(tree, ctx, Val(i))::N
                    end,
                )
            end
        end
        return out::N
    end
end

@generated function _make_derivative_operators(
    operators::OperatorEnum{<:Tuple{Vararg{Tuple,nops}}}
) where {nops}
    quote
        return OperatorEnum(
            Base.Cartesian.@ntuple(  # COV_EXCL_LINE
                $nops,
                i -> _make_derivative_operators(operators[i], Val(i)),
            ),
        )
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

        return Base.Cartesian.@ntuple(  # COV_EXCL_LINE
            $((degree + 1) * nops),
            new_op_index -> Base.Cartesian.@nif(  # COV_EXCL_LINE
                $(degree + 1),
                arg_index_plus_1 -> new_op_index <= arg_index_plus_1 * $nops,
                arg_index_plus_1 -> begin  # COV_EXCL_LINE
                    if arg_index_plus_1 == 1  # COV_EXCL_LINE
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
