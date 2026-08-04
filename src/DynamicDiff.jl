module DynamicDiff

export D, assume_holomorphic

using DispatchDoctor: @stable

@stable default_mode = "disable" begin
    include("utils.jl")
    include("operator_derivatives.jl")
    include("expression_derivative.jl")
end

end
