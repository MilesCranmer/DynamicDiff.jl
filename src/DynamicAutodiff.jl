module DynamicAutodiff

using DispatchDoctor: @stable

@stable default_mode = "disable" begin
    include("derivative.jl")
end

end
