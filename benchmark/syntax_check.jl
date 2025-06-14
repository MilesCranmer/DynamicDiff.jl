# Simple syntax check - just try to parse the file
try
    include("benchmarks.jl")
    println("✓ Syntax check passed - benchmarks.jl parsed successfully")
    println("✓ SUITE has $(length(SUITE)) categories: $(collect(keys(SUITE)))")
    
    # Check structure
    for category in keys(SUITE)
        println("✓ $category has types: $(collect(keys(SUITE[category])))")
        for T in keys(SUITE[category])
            benchmarks = collect(keys(SUITE[category][T]))
            println("  ✓ $T has $(length(benchmarks)) benchmarks")
        end
    end
    
catch e
    println("✗ Syntax error: $e")
    rethrow(e)
end