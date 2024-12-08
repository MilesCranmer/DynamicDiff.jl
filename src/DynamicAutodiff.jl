module DynamicAutodiff

export D

using DispatchDoctor: @stable

@stable default_mode = "disable" begin
    include("derivative.jl")
    include("operator_derivatives.jl")
end

end
