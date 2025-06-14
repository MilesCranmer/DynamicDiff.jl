# DynamicDiff.jl Benchmarks

This directory contains benchmark suites for testing the performance of DynamicDiff.jl's symbolic differentiation capabilities.

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
# Run only first-order derivative benchmarks
first_order_results = run(SUITE["first_order"])

# Run only higher-order derivative benchmarks
higher_order_results = run(SUITE["higher_order"])

# Run only operator-specific benchmarks
operator_results = run(SUITE["operators"])

# Run only evaluation benchmarks
evaluation_results = run(SUITE["evaluation"])

# Run only custom operator benchmarks
custom_results = run(SUITE["custom"])
```

## Benchmark Categories

### First-Order Derivatives (`SUITE["first_order"]`)
Tests the performance of computing first-order derivatives for:
- Simple expressions with basic operators (+, -, *, /)
- Expressions of different sizes (5, 10, 20 nodes)
- Both Float32 and Float64 precision

### Higher-Order Derivatives (`SUITE["higher_order"]`)
Tests the performance of computing:
- Second-order derivatives
- Third-order derivatives  
- Mixed partial derivatives

### Operator Types (`SUITE["operators"]`)
Tests differentiation performance for different types of operators:
- Trigonometric functions (sin, cos)
- Hyperbolic functions (sinh, cosh)
- Special functions (abs, sign, inv)

### Evaluation (`SUITE["evaluation"]`)
Tests the performance of:
- Evaluating computed derivatives
- Combined derivative computation and evaluation

### Custom Operators (`SUITE["custom"]`)
Tests differentiation of expressions containing user-defined operators.

## Results Analysis

To analyze and compare results:

```julia
# Print median times
BenchmarkTools.median(results)

# Get memory allocation information
BenchmarkTools.memory(results)

# Compare different configurations
judge(results_v1, results_v2)
```

## Extending the Benchmarks

To add new benchmarks:

1. Create a new benchmark function following the pattern of existing functions
2. Add it to the main `SUITE` at the end of `benchmarks.jl`
3. Document the new benchmark category in this README

## Dependencies

- BenchmarkTools.jl: For benchmark infrastructure
- DynamicDiff.jl: The package being benchmarked
- DynamicExpressions.jl: For expression construction
- SymbolicRegression.jl: For ComposableExpression support
- Random.jl: For generating random test expressions