# DynamicDiff.jl Benchmarks

This directory contains benchmark suites for testing the performance of DynamicDiff.jl's symbolic differentiation operator `D`.

## Setup

First, instantiate the benchmark environment:

```julia
using Pkg
Pkg.activate("benchmark")
Pkg.instantiate()
```

## Running Benchmarks

To run the complete benchmark suite:

```julia
include("benchmarks.jl")
using BenchmarkTools

# Run all benchmarks
results = run(SUITE)
```

To run specific benchmark categories:

```julia
# Run basic operator benchmarks
basic_results = run(SUITE["basic"])

# Run extended operator benchmarks  
extended_results = run(SUITE["extended"])

# Run custom operator benchmarks
custom_results = run(SUITE["custom"])
```

## Benchmark Categories

### Basic Operators (`SUITE["basic"]`)
Tests `D` performance with fundamental operators:
- **Operators**: `+`, `-`, `*`, `/`, `sin`, `cos`
- **Expression sizes**: 5, 10, 20 nodes
- **Derivatives**: 1st and 2nd order
- **Test cases**: 100 random expressions per configuration
- **Types**: Float32 and Float64

### Extended Operators (`SUITE["extended"]`)
Tests `D` performance with a broader operator set:
- **Operators**: `+`, `-`, `*`, `/`, `sin`, `cos`, `sinh`, `cosh`, `exp`, `log`, `abs`, `-`, `inv`
- **Expression size**: 15 nodes
- **Derivatives**: 1st, 2nd, and 3rd order
- **Test cases**: 100 random expressions per configuration
- **Types**: Float32 and Float64

### Custom Operators (`SUITE["custom"]`)
Tests `D` performance with user-defined operators:
- **Custom operators**: `my_op(x) = 2x + 1`, `my_binop(x,y) = x² + y`
- **Expression size**: 10 nodes
- **Derivatives**: 1st and 2nd order
- **Test cases**: 100 random expressions per configuration
- **Types**: Float32 and Float64

## Key Features

- **Focused scope**: Only benchmarks the `D` operator itself
- **Large test sets**: 100 expressions per benchmark (not just 3)
- **No list comprehensions in benchmarks**: All wrapped in helper functions
- **Random expression generation**: Diverse test cases with fixed seed for reproducibility
- **Multiple operator sets**: Tests different complexity levels
- **Higher-order derivatives**: Tests nested `D` operations

## Results Analysis

```julia
# Print median times
BenchmarkTools.median(results)

# Compare different configurations
judge(old_results, new_results)

# Memory usage
BenchmarkTools.memory(results)
```

## Dependencies

- BenchmarkTools.jl: Benchmark infrastructure
- DynamicDiff.jl: The package being benchmarked  
- DynamicExpressions.jl: Expression construction
- SymbolicRegression.jl: ComposableExpression support
- Random.jl: Random expression generation