using DynamicAutodiff
using Test
using Aqua
using JET

@testset "DynamicAutodiff.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(DynamicAutodiff)
    end
    @testset "Code linting (JET.jl)" begin
        JET.test_package(DynamicAutodiff; target_defined_modules = true)
    end
    # Write your tests here.
end
