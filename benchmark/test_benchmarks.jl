include("benchmarks.jl")
using BenchmarkTools

println("Testing if benchmarks run...")

# Test a small subset first
try
    # Test basic benchmarks
    println("Testing basic benchmarks...")
    result = run(SUITE["basic"], verbose=true, seconds=1)
    println("✓ Basic benchmarks work")
    
    # Test extended benchmarks  
    println("Testing extended benchmarks...")
    result = run(SUITE["extended"], verbose=true, seconds=1)
    println("✓ Extended benchmarks work")
    
    # Test custom benchmarks
    println("Testing custom benchmarks...")
    result = run(SUITE["custom"], verbose=true, seconds=1)
    println("✓ Custom benchmarks work")
    
    println("All benchmarks run successfully!")
    
catch e
    println("Error running benchmarks: $e")
    rethrow(e)
end