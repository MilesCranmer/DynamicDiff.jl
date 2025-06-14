# DynamicDiff.jl Benchmarks

Benchmarks for the `D` operator in DynamicDiff.jl.

## Usage

```julia
include("benchmarks.jl")
results = run(SUITE)
```

## Structure

- **`basic`**: Basic operators (+, -, *, /, sin, cos) with sizes 5/10/20 (100/200/400 expressions)
- **`extended`**: Extended operators including sinh, cosh, exp, abs, inv  
- **`custom`**: User-defined operators

Each tests 1st/2nd/3rd order derivatives on Float32/Float64.

## Dependencies

- BenchmarkTools.jl, DynamicDiff.jl, DynamicExpressions.jl