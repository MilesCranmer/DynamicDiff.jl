var documenterSearchIndex = {"docs":
[{"location":"","page":"Home","title":"Home","text":"CurrentModule = DynamicDiff","category":"page"},{"location":"#DynamicDiff","page":"Home","title":"DynamicDiff","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for DynamicDiff.","category":"page"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [DynamicDiff]","category":"page"},{"location":"#DynamicDiff.OperatorDerivative","page":"Home","title":"DynamicDiff.OperatorDerivative","text":"OperatorDerivative{F,degree,arg} <: Function\n\nA callable type representing the partial derivative of an operator. Takes either one (degree=1) or two (degree=2) scalar arguments. Returns a scalar.\n\nParameters\n\nF: The type of the original operator\ndegree: The arity of the operator (1 for unary, 2 for binary)\narg: Which argument to take the derivative with respect to\n\nFields\n\nop: The actual function performing the partial derivative.\n\n\n\n\n\n","category":"type"},{"location":"#DynamicDiff.D-Tuple{DynamicExpressions.ExpressionModule.AbstractExpression, Integer}","page":"Home","title":"DynamicDiff.D","text":"D(ex::AbstractExpression, feature::Integer)\n\nCompute the derivative of ex with respect to the feature-th variable. Returns a new expression with an expanded set of operators.\n\n\n\n\n\n","category":"method"},{"location":"#DynamicDiff.operator_derivative-Union{Tuple{arg}, Tuple{degree}, Tuple{F}, Tuple{F, Val{degree}, Val{arg}}} where {F, degree, arg}","page":"Home","title":"DynamicDiff.operator_derivative","text":"operator_derivative(op::F, ::Val{degree}, ::Val{arg}) where {F,degree,arg}\n\nCreate an OperatorDerivative instance holding the partial derivative of the given operator for the given argument.\n\nArguments\n\nop: The operator to differentiate\ndegree: The arity of the operator (1 for unary, 2 for binary)\narg: Which argument to take the derivative with respect to\n\n\n\n\n\n","category":"method"}]
}
