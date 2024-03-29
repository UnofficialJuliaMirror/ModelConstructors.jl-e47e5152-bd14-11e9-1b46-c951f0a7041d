import Base: <=

Interval{T} = Tuple{T,T}
"""
```
Transform
```

Subtypes of the abstract Transform type indicate how a `Parameter`'s
value is transformed from model space (which can be bounded to a
limited section of the real line) to the entire real line (which is
necessary for mode-finding using csminwel). The transformation is
performed by the `transform_to_real_line` function, and is reversed by the
`transform_to_model_space` function.
"""
abstract type Transform end

struct Untransformed <: Transform end
struct SquareRoot    <: Transform end
struct Exponential   <: Transform end

Base.show(io::IO, t::Untransformed) = @printf io "x -> x\n"
Base.show(io::IO, t::SquareRoot)    = @printf io "x -> (a+b)/2 + (b-a)/2*c*x/sqrt(1 + c^2 * x^2)\n"
Base.show(io::IO, t::Exponential)   = @printf io "x -> b + (1/c) * log(x-a)\n"

"""
```
AbstractParameter{T<:Number}
```

The AbstractParameter type is the common supertype of all model
parameters, including steady-state values.  Its subtype structure is
as follows:

-`AbstractParameter{T<:Number}`: The common abstract supertype for all parameters.
    -`Parameter{S<:Real,T<:Number, U<:Transform}`: The abstract supertype for parameters that are directly estimated.
        -`UnscaledParameter{S<:Real, T<:Number, U:<Transform}`: Concrete type for parameters that do not need to be scaled for equilibrium conditions.
        -`ScaledParameter{S<:Real, T<:Number, U:<Transform}`: Concrete type for parameters that are scaled for equilibrium conditions.
    -`SteadyStateParameter{T<:Number}`: Concrete type for steady-state parameters.
"""
abstract type AbstractParameter{T<:Number} end
abstract type AbstractVectorParameter{V<:Vector, T<:Number} end
#abstract type AbstractArrayParameter{A<:Array} end

"""
```
Parameter{ S<:Real, T<:Number, U<:Transform} <: AbstractParameter{T}
```

The Parameter type is the common supertype of time-invariant, non-steady-state model
parameters. It has 2 subtypes, `UnscaledParameter` and `ScaledParameter`.
`ScaledParameter`s are parameters whose values are scaled when used in the model's
equilibrium conditions. The scaled value is stored for convenience, and updated when the
parameter's value is updated.

The Parameter type has separate `T` and `S` types to allow for
automatic differentiation, which will make the type of `S` a Dual type. By specifying
this difference, while we cannot enforce `T` and `S` to always sensibly match
each others types, we can avoid the issue of having to recast the types of fields
with type `T` to be Duals as well.
"""
abstract type Parameter{S<:Real,T,U<:Transform} <: AbstractParameter{T} end
abstract type VectorParameter{V,T,U<:Transform} <: AbstractVectorParameter{V,T} end
#abstract type ArrayParameter{A,U<:Transform} <: AbstractArrayParameter{A} end

# ParameterVector is a wrapper for a vector
# that takes any subtype of AbstractParameter, but it is not
# an "abstract" type since we are not intending
# to define subtypes of ParameterVector.
ParameterVector{T}       =  Vector{AbstractParameter{T}}
VectorParameterVector{V,T} =  Vector{AbstractVectorParameter{V,T}}
#ArrayParameterVector{A}  =  Vector{AbstractArrayParameter{A}}
NullablePriorUnivariate   =  Nullables.Nullable{ContinuousUnivariateDistribution}
NullablePriorMultivariate =  Nullables.Nullable{ContinuousMultivariateDistribution}

"""
```
UnscaledParameter{S<:Real,T<:Number,U<:Transform} <: Parameter{S,T,U}
```

Time-invariant model parameter whose value is used as-is in the model's equilibrium
conditions.

#### Fields
- `key::Symbol`: Parameter name. For maximum clarity, `key`
  should conform to the guidelines established in the DSGE Style Guide.
- `value::S`: Parameter value. Initialized in model space (guaranteed
  to be between `valuebounds`), but can be transformed between model
  space and the real line via calls to `transform_to_real_line` and
`transform_to_model_space`.
- `valuebounds::Interval{T}`: Bounds for the parameter's value in model space.
- `transform_parameterization::Interval{T}`: Parameters used to
  transform `value` between model space and the real line.
- `transform::U`: Transformation used to transform `value` between
  model space and real line.
- `prior::NullablePrior`: Prior distribution for parameter value.
- `fixed::Bool`: Indicates whether the parameter's value is fixed rather than estimated.
- `description::String`:  A short description of the parameter's economic
  significance.
- `tex_label::String`: String for printing the parameter name to LaTeX.
"""
mutable struct UnscaledParameter{S,T,U} <: Parameter{S,T,U}
    key::Symbol
    value::S                                # parameter value in model space
    valuebounds::Interval{T}                # bounds of parameter value
    transform_parameterization::Interval{T} # parameters for transformation
    transform::U                            # transformation between model space and real line for optimization
    prior::NullablePriorUnivariate                    # prior distribution
    fixed::Bool                             # is this parameter fixed at some value?
    description::String
    tex_label::String               # LaTeX label for printing
end

mutable struct UnscaledVectorParameter{V,T,U} <: VectorParameter{V,T,U}
    key::Symbol
    value::V                                # parameter value in model space
    valuebounds::Interval{T}                # bounds of parameter value
    transform_parameterization::Interval{T} # parameters for transformation
    transform::U                            # transformation between model space and real line for optimization
    prior::NullablePriorMultivariate                   # prior distribution
    fixed::Bool                             # is this parameter fixed at some value?
    description::String
    tex_label::String               # LaTeX label for printing
end


"""
```
ScaledParameter{S,T,U} <: Parameter{S,T,U}
```

Time-invariant model parameter whose value is scaled for use in the model's equilibrium
conditions.

#### Fields

- `key::Symbol`: Parameter name. For maximum clarity, `key`
  should conform to the guidelines established in the DSGE Style Guide.
- `value::T`: The parameter's unscaled value. Initialized in model
  space (guaranteed to be between `valuebounds`), but can be
  transformed between model space and the real line via calls to
  `transform_to_real_line` and `transform_to_model_space`.
- `scaledvalue::T`: Parameter value scaled for use in `eqcond.jl`
- `valuebounds::Interval{T}`: Bounds for the parameter's value in model space.
- `transform_parameterization::Interval{T}`: Parameters used to
  transform `value` between model space and the real line.
- `transform::U`: The transformation used to convert `value` between model space and the
  real line, for use in optimization.
- `prior::NullablePrior`: Prior distribution for parameter value.
- `fixed::Bool`: Indicates whether the parameter's value is fixed rather than estimated.
- `scaling::Function`: Function used to scale parameter value for use in equilibrium
  conditions.
- `description::String`: A short description of the parameter's economic
  significance.
- `tex_label::String`: String for printing parameter name to LaTeX.
"""
mutable struct ScaledParameter{S,T,U} <: Parameter{S,T,U}
    key::Symbol
    value::S
    scaledvalue::S
    valuebounds::Interval{T}
    transform_parameterization::Interval{T}
    transform::U
    prior::NullablePriorUnivariate
    fixed::Bool
    scaling::Function
    description::String
    tex_label::String
end

mutable struct ScaledVectorParameter{V,T,U} <: VectorParameter{V,T,U}
    key::Symbol
    value::V
    scaledvalue::V
    valuebounds::Interval{T}
    transform_parameterization::Interval{T}
    transform::U
    prior::NullablePriorMultivariate
    fixed::Bool
    scaling::Function
    description::String
    tex_label::String
end


"""
```
SteadyStateParameter{T} <: AbstractParameter{T}
```

Steady-state model parameter whose value depends upon the value of other (non-steady-state)
`Parameter`s. `SteadyStateParameter`s must be constructed and added to an instance of a
model object `m` after all other model `Parameter`s have been defined. Once added to `m`,
`SteadyStateParameter`s are stored in `m.steady_state`. Their values are calculated and set
by `steadystate!(m)`, rather than being estimated directly. `SteadyStateParameter`s do not
require transformations from the model space to the real line or scalings for use in
equilibrium conditions.

#### Fields

- `key::Symbol`: Parameter name. Should conform to the guidelines
  established in the DSGE Style Guide.
- `value::T`: The parameter's steady-state value.
- `description::String`: Short description of the parameter's economic significance.
- `tex_label::String`: String for printing parameter name to LaTeX.
"""
mutable struct SteadyStateParameter{T} <: AbstractParameter{T}
    key::Symbol
    value::T
    description::String
    tex_label::String
end

"""
```
SteadyStateValueGrid{T} <: AbstractParameter{T}
```

Steady-state model parameter grid (for heterogeneous agent models) whose value is calculated by an
iterative procedure.
`SteadyStateParameterGrid`s must be constructed and added to an instance of a
model object `m` after all other model `Parameter`s have been defined. Once added to `m`,
`SteadyStateParameterGrid`s are stored in `m.steady_state`. Their values are calculated and set
by `steadystate!(m)`, rather than being estimated directly. `SteadyStateParameter`s do not
require transformations from the model space to the real line or scalings for use in
equilibrium conditions.

#### Fields

- `key::Symbol`: Parameter name. Should conform to the guidelines
  established in the DSGE Style Guide.
- `value::Array{T}`: The parameter's steady-state value grid.
- `description::String`: Short description of the parameter's economic significance.
- `tex_label::String`: String for printing parameter name to LaTeX.
"""
mutable struct SteadyStateParameterGrid{T} <: AbstractParameter{T}
    key::Symbol
    value::Array{T}
    description::String
    tex_label::String
end

function SteadyStateParameterGrid(key::Symbol,
                                  value::Array{T};
                                  description::String = "No description available",
                                  tex_label::String = "") where {T<:Number}

    return SteadyStateParameterGrid{T}(key, value, description, tex_label)
end

"""
```
SteadyStateParameterArray{T} <: AbstractParameter{T}
```
Steady-state model parameter whose value is an Array and
 depends upon the value of other (non-steady-state)
`Parameter`s. `SteadyStateParameterArray`s must be constructed and added to an instance of a
model object `m` after all other model `Parameter`s have been defined. Once added to `m`,
`SteadyStateParameterArray`s are stored in `m.steady_state`. Their values are calculated and set
by `steadystate!(m)`, rather than being estimated directly. `SteadyStateParameterArray`s do not
require transformations from the model space to the real line or scalings for use in
equilibrium conditions.

#### Fields

- `key::Symbol`: Parameter name. Should conform to the guidelines
  established in the DSGE Style Guide.
- `value::Array{T}`: The parameter's steady-state values.
- `description::String`: Short description of the parameter's economic significance.
- `tex_label::String`: String for printing parameter name to LaTeX.
"""
mutable struct SteadyStateParameterArray{T} <: AbstractParameter{T}
    key::Symbol
    value::Array{T}
    description::String
    tex_label::String
end

"""
```
SteadyStateParameterArray{T<:Number}(key::Symbol, value::Array{T};
                                description::String = "",
                                tex_label::String = "")
```

SteadyStateParameter constructor with optional `description` and `tex_label` arguments.
"""
function SteadyStateParameterArray(key::Symbol,
                                   value::Array{T};
                                   description::String = "No description available",
                                   tex_label::String = "") where {T<:Number}

    return SteadyStateParameterArray(key, value, description, tex_label)
end

# TypeError: non-boolean (BitArray{1}) used in boolean context
# gets thrown when we print the value.

function Base.show(io::IO, p::SteadyStateParameterArray{T}) where {T}
    @printf io "%s\n" typeof(p)
    @printf io "(:%s)\n%s\n"      p.key p.description
    @printf io "LaTeX label: %s\n"     p.tex_label
    @printf io "-----------------------------\n"
    @printf io "value:        [%+6f,...,%+6f]\n" p.value[1] p.value[end]
end

hasprior(p::Union{Parameter, VectorParameter}) = !isnull(p.prior)

NullableOrPriorUnivariate = Union{NullablePriorUnivariate, ContinuousUnivariateDistribution}
NullableOrPriorMultivariate = Union{NullablePriorMultivariate, ContinuousMultivariateDistribution}

# We want to use value field from UnscaledParameters and
# SteadyStateParameters in computation, so we alias their union here.
UnscaledOrSteadyState = Union{UnscaledParameter, SteadyStateParameter}

"""
```
ParamBoundsError <: Exception
```

A `ParamBoundsError` is thrown upon an attempt to assign a parameter value that is not
between `valuebounds`.
"""
mutable struct ParamBoundsError <: Exception
    msg::String
end
ParamBoundsError() = ParamBoundsError("Value not between valuebounds")
Base.showerror(io::IO, ex::ParamBoundsError) = print(io, ex.msg)

"""
```
parameter{S,T,U<:Transform}(key::Symbol, value::S, valuebounds = (value,value),
                          transform_parameterization = (value,value),
                          transform = Untransformed(), prior = NullablePrior();
                          fixed = true, scaling::Function = identity, description = "",
                          tex_label::String = "")
```

By default, returns a fixed `UnscaledParameter` object with key `key`
and value `value`. If `scaling` is given, a `ScaledParameter` object
is returned.
"""
function parameter(key::Symbol,
                   value::Union{S,V},
                   valuebounds::Interval{T} = (value,value),
                   transform_parameterization::Interval{T} = (value,value),
                   transform::U             = Untransformed(),
                   prior::Union{NullableOrPriorUnivariate, NullableOrPriorMultivariate} = NullablePriorUnivariate();
                   fixed::Bool              = true,
                   scaling::Function        = identity,
                   description::String = "No description available.",
                   tex_label::String = "") where {V<:Vector, S<:Real, T <: Float64, U <:Transform}

    # If fixed=true, force bounds to match and leave prior as null.  We need to define new
    # variable names here because of lexical scoping.

    valuebounds_new = valuebounds
    transform_parameterization_new = transform_parameterization
    transform_new = transform
    U_new = U
    prior_new = prior

    if fixed
        # value[1] because need to deal with case in which value is a vector (but if only Float, [1] just takes the Float
        transform_parameterization_new = (value[1],value[1])  # value is transformed already
        transform_new = Untransformed()                 # fixed priors should stay untransformed
        U_new = Untransformed

        if isa(transform, Untransformed)
            valuebounds_new = (value[1],value[1])
        end
    else
        transform_parameterization_new = transform_parameterization
    end

    # ensure that we have a Nullable{Distribution}, if not construct one
    prior_new = if isa(prior_new, NullableOrPriorUnivariate)
        !isa(prior_new,NullablePriorUnivariate) ? NullablePriorUnivariate(prior_new) : prior_new
    elseif isa(prior_new, NullableOrPriorMultivariate)
        !isa(prior_new,NullablePriorMultivariate) ? NullablePriorMultivariate(prior_new) : prior_new
    else
        @error "Must be a PriorOrNullable or PriorOrNullableMultivariate"
    end

    if scaling == identity
        if typeof(value) <: Real
            return UnscaledParameter{S,T,U_new}(key, value, valuebounds_new,
                                              transform_parameterization_new, transform_new,
                                              prior_new, fixed, description, tex_label)
        elseif typeof(value) <: Vector
            return UnscaledVectorParameter{V,T,U_new}(key, value, valuebounds_new,
                                              transform_parameterization_new, transform_new,
                                              prior_new, fixed, description, tex_label)
        else
            @error "Type of value not yet supported"
        end
    else
        if typeof(value) <: Real
            return ScaledParameter{S,T,U_new}(key, value, scaling(value), valuebounds_new,
                                            transform_parameterization_new, transform_new,
                                            prior_new, fixed, scaling, description, tex_label)
        elseif typeof(value) <: Vector
            return ScaledVectorParameter{V,T,U_new}(key, value, scaling(value), valuebounds_new,
                                            transform_parameterization_new, transform_new,
                                            prior_new, fixed, scaling, description, tex_label)
        end
    end
end

function parameter(key::Symbol,
                   prior::Union{ContinuousUnivariateDistribution, ContinuousMultivariateDistribution};
                   fixed::Bool = false,
                   description::String = "No description available",
                   tex_label::String = "")
    val = length(prior) > 1 ? repeat([NaN], length(prior)) : NaN
    return parameter(key, val, (NaN, NaN), (NaN, NaN), Untransformed(), prior, fixed = fixed, scaling = identity, description = description, tex_label = tex_label)
end


"""
```
SteadyStateParameter(key::Symbol, value::T; description::String = "",
                      tex_label::String = "") where {T <: Number}
```

SteadyStateParameter constructor with optional `description` and `tex_label` arguments.
"""
function SteadyStateParameter(key::Symbol, value::T;
                              description::String = "No description available",
                              tex_label::String = "") where {T <: Number}
    return SteadyStateParameter(key, value, description, tex_label)
end


"""
```
parameter(p::UnscaledParameter{S,T,U}, newvalue::S) where {S<:Real,T<:Number,U<:Transform}
```

Returns an UnscaledParameter with value field equal to `newvalue`. If `p` is a fixed
parameter, it is returned unchanged.
"""
function parameter(p::UnscaledParameter{S,T,U}, newvalue::Snew;
                   change_value_type::Bool = false) where {S<:Real, Snew<:Real, T <: Number, U <: Transform}
    p.fixed && return p    # if the parameter is fixed, don't change its value
    if !change_value_type && (typeof(p.value) != typeof(newvalue))
        error("Type of newvalue $(newvalue) does not match the type of the current value for parameter $(string(p.key)). Set keyword change_value_type = true if you want to overwrite the type of the parameter value.")
    end
    a,b = p.valuebounds
    if !(a <= newvalue <= b)
        throw(ParamBoundsError("New value of $(string(p.key)) ($(newvalue)) is out of bounds ($(p.valuebounds))"))
    end
    if change_value_type
        UnscaledParameter{Snew,T,U}(p.key, newvalue, p.valuebounds, p.transform_parameterization,
                                 p.transform, p.prior, p.fixed, p.description, p.tex_label)
    else
        UnscaledParameter{S,T,U}(p.key, newvalue, p.valuebounds, p.transform_parameterization,
                                 p.transform, p.prior, p.fixed, p.description, p.tex_label)
end
end

function parameter(p::UnscaledVectorParameter{V,T,U}, newvalue::V) where {V <: Vector, T <: Number, U <: Transform}
    p.fixed && return p    # if the parameter is fixed, don't change its value
    a,b = p.valuebounds
    if !all(a .<= newvalue .<= b)
        throw(ParamBoundsError("New value of $(string(p.key)) ($(newvalue)) is out of bounds ($(p.valuebounds))"))
    end
    UnscaledVectorParameter{V,T,U}(p.key, newvalue, p.valuebounds, p.transform_parameterization,
                           p.transform, p.prior, p.fixed, p.description, p.tex_label)
end


"""
```
parameter(p::ScaledParameter{S,T,U}, newvalue::S) where {S<:Real, T<:Number,U<:Transform}
```

Returns a ScaledParameter with value field equal to `newvalue` and scaledvalue field equal
to `p.scaling(newvalue)`. If `p` is a fixed parameter, it is returned unchanged.
"""
function parameter(p::ScaledParameter{S,T,U}, newvalue::Snew;
                   change_value_type::Bool = false) where {S<:Real, Snew<:Real, T <: Number, U <: Transform}
    p.fixed && return p    # if the parameter is fixed, don't change its value
    if !change_value_type && (typeof(p.value) != typeof(newvalue))
        error("Type of newvalue $(newvalue) does not match value of parameter $(string(p.key)).")
    end
    a,b = p.valuebounds
    if !(a <= newvalue <= b)
        throw(ParamBoundsError("New value of $(string(p.key)) ($(newvalue)) is out of bounds ($(p.valuebounds))"))
    end
    if change_value_type
        ScaledParameter{Snew,T,U}(p.key, newvalue, p.scaling(newvalue), p.valuebounds,
                               p.transform_parameterization, p.transform, p.prior, p.fixed,
                               p.scaling, p.description, p.tex_label)
    else
        ScaledParameter{S,T,U}(p.key, newvalue, p.scaling(newvalue), p.valuebounds,
                               p.transform_parameterization, p.transform, p.prior, p.fixed,
                               p.scaling, p.description, p.tex_label)
    end
end

function parameter(p::ScaledVectorParameter{V,T,U}, newvalue::V) where {V <: Vector, T <: Number, U <: Transform}
    p.fixed && return p    # if the parameter is fixed, don't change its value
    a,b = p.valuebounds
    if !all(a .<= newvalue .<= b)
        throw(ParamBoundsError("New value of $(string(p.key)) ($(newvalue)) is out of bounds ($(p.valuebounds))"))
    end
    ScaledVectorParameter{V,T,U}(p.key, newvalue, p.scaling.(newvalue), p.valuebounds,
                         p.transform_parameterization, p.transform, p.prior, p.fixed,
                         p.scaling, p.description, p.tex_label)
end


function Base.show(io::IO, p::Parameter{S,T,U}) where {S,T, U}
    @printf io "%s\n" typeof(p)
    @printf io "(:%s)\n%s\n"      p.key p.description
    @printf io "LaTeX label: %s\n"     p.tex_label
    @printf io "-----------------------------\n"
    #@printf io "real value:        %+6f\n" transform_to_real_line(p)
    @printf io "unscaled, untransformed value:        %+6f\n" p.value
    isa(p,ScaledParameter) && @printf "scaled, untransformed value:        %+6f\n" p.scaledvalue
    #!isa(U(),Untransformed) && @printf io "transformed value: %+6f\n" p.value

    if hasprior(p)
        @printf io "prior distribution:\n\t%s\n" get(p.prior)
    else
        @printf io "prior distribution:\n\t%s\n" "no prior"
    end

    @printf io "transformation for csminwel:\n\t%s" U()
    @printf io "parameter is %s\n" p.fixed ? "fixed" : "not fixed"
end

function Base.show(io::IO, p::VectorParameter{V,T,U}) where {V,T, U}
    @printf io "%s\n" typeof(p)
    @printf io "(:%s)\n%s\n"      p.key p.description
    @printf io "LaTeX label: %s\n"     p.tex_label
    @printf io "-----------------------------\n"
    #@printf io "real value:        %+6f\n" transform_to_real_line(p)
    join([@printf io "%+6f\n" x for x in p.value], ", ")
    #isa(p,ScaledParameter) && @printf "scaled, untransformed value:        %+6f\n" p.scaledvalue
    #!isa(U(),Untransformed) && @printf io "transformed value: %+6f\n" p.value

    if hasprior(p)
        @printf io "prior distribution:\n\t%s\n" get(p.prior)
    else
        @printf io "prior distribution:\n\t%s\n" "no prior"
    end
    @printf io "transformation for csminwel:\n\t%s" U()
    @printf io "parameter is %s\n" p.fixed ? "fixed" : "not fixed"
end


function Base.show(io::IO, p::SteadyStateParameter{T}) where {T}
    @printf io "%s\n"                 typeof(p)
    @printf io "(:%s)\n%s\n"          p.key p.description
    @printf io "LaTeX label: %s\n"    p.tex_label
    @printf io "-----------------------------\n"
    @printf io "value:        %+6f\n" p.value
end

function Base.show(io::IO, p::SteadyStateParameterGrid{T}) where {T}
    @printf io "%s\n"                      typeof(p)
    @printf io "(:%s)\n%s\n"               p.key p.description
    @printf io "LaTeX label: %s\n"         p.tex_label
    @printf io "-----------------------------\n"
    @printf io "value:        [%f,...,%f]" p.value[1] p.value[end]
end

"""
```
transform_to_model_space{S<:Real,T<:Number, U<:Transform}(p::Parameter{S,T,U}, x::S)
```

Transforms `x` from the real line to lie between `p.valuebounds` without updating `p.value`.
The transformations are defined as follows, where (a,b) = p.transform_parameterization and c
a scalar (default=1):

- Untransformed: `x`
- SquareRoot:    `(a+b)/2 + (b-a)/2 * c * x/sqrt(1 + c^2 * x^2)`
- Exponential:   `a + exp(c*(x-b))`
"""
transform_to_model_space(p::Parameter{S,<:Number,Untransformed}, x::S) where S = x
function transform_to_model_space(p::Parameter{S,<:Number,SquareRoot}, x::S) where S
    (a,b), c = p.transform_parameterization, one(S)
    (a+b)/2 + (b-a)/2*c*x/sqrt(1 + c^2 * x^2)
end
function transform_to_model_space(p::Parameter{S,<:Number,Exponential}, x::S) where S
    (a,b), c = p.transform_parameterization, one(S)
    a + exp(c*(x-b))
end

transform_to_model_space(pvec::ParameterVector, values::Vector{S}) where S = map(transform_to_model_space, pvec, values)

"""
```
differentiate_transform_to_model_space{S<:Real,T<:Number, U<:Transform}(p::Parameter{S,T,U}, x::S)
```

Differentiates the transform of `x` from the real line to lie between `p.valuebounds`
The transformations are defined as follows, where (a,b) = p.transform_parameterization and c
a scalar (default=1):

- Untransformed: `x`
- SquareRoot:    `(a+b)/2 + (b-a)/2 * c * x/sqrt(1 + c^2 * x^2)`
- Exponential:   `a + exp(c*(x-b))`

Their gradients are therefore

- Untransformed: `1`
- SquareRoot:    `(b-a)/2 * c / (1 + c^2 * x^2)^(3/2)`
- Exponential:   `c * exp(c*(x-b))`
"""
differentiate_transform_to_model_space(p::Parameter{S,<:Number,Untransformed}, x::S) where S = one(S)
function differentiate_transform_to_model_space(p::Parameter{S,<:Number,SquareRoot}, x::S) where S
    (a,b), c = p.transform_parameterization, one(S)
    (b-a)/2 * c / (1 + c^2 * x^2)^(3/2)
end
function differentiate_transform_to_model_space(p::Parameter{S,<:Number,Exponential}, x::S) where S
    (a,b), c = p.transform_parameterization, one(S)
    c * exp(c*(x-b))
end
differentiate_transform_to_model_space(pvec::ParameterVector, values::Vector{S}) where S = map(differentiate_transform_to_model_space, pvec, values)

"""
```
transform_to_real_line(p::Parameter{S,T,U}, x::S = p.value) where {S<:Real, T<:Number, U<:Transform}
```

Transforms `p.value` from model space (between `p.valuebounds`) to the real line, without updating
`p.value`. The transformations are defined as follows,
where (a,b) = p.transform_parameterization, c a scalar (default=1), and x = p.value:

- Untransformed: x
- SquareRoot:   (1/c)*cx/sqrt(1 - cx^2), where cx =  2 * (x - (a+b)/2)/(b-a)
- Exponential:   b + (1 / c) * log(x-a)
"""
transform_to_real_line(p::Parameter{S,<:Number,Untransformed}, x::S = p.value) where S = x
function transform_to_real_line(p::Parameter{S,<:Number,SquareRoot}, x::S = p.value) where S
    (a,b), c = p.transform_parameterization, one(S)
    cx = 2. * (x - (a+b)/2.)/(b-a)
    if cx^2 >1
        println("Parameter is: $(p.key)")
        println("a is $a")
        println("b is $b")
        println("x is $x")
        println("cx is $cx")
        error("invalid paramter value")
    end
    (1/c)*cx/sqrt(1 - cx^2)
end
function transform_to_real_line(p::Parameter{S,<:Number,Exponential}, x::S = p.value) where S
    (a,b),c = p.transform_parameterization,one(S)
    b + (1 ./ c) * log(x-a)
end

transform_to_real_line(pvec::ParameterVector, values::Vector{S}) where S  = map(transform_to_real_line, pvec, values)
transform_to_real_line(pvec::ParameterVector{S}) where S = map(transform_to_real_line, pvec)

"""
```
differentiate_transform_to_real_line{S<:Real,T<:Number, U<:Transform}(p::Parameter{S,T,U}, x::S)
```

Differentiates the transform of `x` from the model space lying between `p.valuebounds` to the real line.
The transformations are defined as follows, where (a,b) = p.transform_parameterization and c
a scalar (default=1):

- Untransformed: x
- SquareRoot:   (1/c)*cx/sqrt(1 - cx^2), where cx =  2 * (x - (a+b)/2)/(b-a)
- Exponential:   b + (1 / c) * log(x-a)

Their gradients are therefore

- Untransformed: `1`
- SquareRoot:    `(1/c) * (1 / ( 1 - cx^2)^(-3/2)) * (2/(b-a))`
- Exponential:   `1 / (c * (x - a))`
"""
differentiate_transform_to_real_line(p::Parameter{S,<:Number,Untransformed}, x::S) where S = one(S)
function differentiate_transform_to_real_line(p::Parameter{S,<:Number,SquareRoot}, x::S) where S
    (a,b), c = p.transform_parameterization, one(S)
    cx = 2 * (x - (a+b)/2)/(b-a)
    (1/c) * (1 / (1 - cx^2)^(-3/2)) * (2/(b-a))
end
function differentiate_transform_to_real_line(p::Parameter{S,<:Number,Exponential}, x::S) where S
    (a,b), c = p.transform_parameterization, one(S)
    1 / (c * (x - a))
end
differentiate_transform_to_real_line(pvec::ParameterVector, values::Vector{S}) where S = map(differentiate_transform_to_real_line, pvec, values)
differentiate_transform_to_real_line(pvec::ParameterVector{S}) where S = map(differentiate_transform_to_real_line, pvec)

# define operators to work on parameters

Base.convert(::Type{S}, p::UnscaledParameter) where {S<:Real}     = convert(S,p.value)
Base.convert(::Type{T}, p::UnscaledVectorParameter) where {T <: Vector}     = convert(T,p.value)
Base.convert(::Type{S}, p::ScaledParameter) where {S<:Real}       = convert(S,p.scaledvalue)
Base.convert(::Type{T}, p::ScaledVectorParameter) where {T <: Vector}       = convert(T,p.scaledvalue)

Base.convert(::Type{S}, p::SteadyStateParameter) where {S<:Real}  = convert(S,p.value)
Base.convert(::Type{ForwardDiff.Dual{T,V,N}}, p::UnscaledParameter) where {T,V,N} = convert(V,p.value)
Base.convert(::Type{ForwardDiff.Dual{T,V,N}}, p::ScaledParameter) where {T,V,N} = convert(V,p.scaledvalue)

Base.promote_rule(::Type{AbstractParameter{S}}, ::Type{U}) where {S<:Real, U<:Number} = promote_rule(S,U)
Base.promote_rule(::Type{AbstractVectorParameter{T}}, ::Type{U}) where {T<:Vector, U<:Vector} = promote_rule(T,U)

# Define scalar operators on parameters
for op in (:(Base.:+),
           :(Base.:-),
           :(Base.:*),
           :(Base.:/),
           :(Base.:^))

    @eval ($op)(p::UnscaledOrSteadyState, q::UnscaledOrSteadyState) = ($op)(p.value, q.value)
    @eval ($op)(p::UnscaledOrSteadyState, x::Integer)            = ($op)(p.value, x)
    @eval ($op)(p::UnscaledOrSteadyState, x::Number)            = ($op)(p.value, x)
    @eval ($op)(x::Number, p::UnscaledOrSteadyState)            = ($op)(x, p.value)

    @eval ($op)(p::ScaledParameter, q::ScaledParameter) = ($op)(p.scaledvalue, q.scaledvalue)
    @eval ($op)(p::ScaledParameter, x::Integer)            = ($op)(p.scaledvalue, x)
    @eval ($op)(p::ScaledParameter, x::Number)            = ($op)(p.scaledvalue, x)
    @eval ($op)(x::Number, p::ScaledParameter)            = ($op)(x, p.scaledvalue)

    @eval ($op)(p::ScaledParameter, q::UnscaledOrSteadyState) = ($op)(p.scaledvalue, q.value)
    @eval ($op)(p::UnscaledOrSteadyState, q::ScaledParameter) = ($op)(p.value, q.scaledvalue)
end

for op in (:(Base.:+),
           :(Base.:-),
           :(Base.:*),
           :(Base.:/),
           :(Base.:^))

    @eval ($op)(p::UnscaledVectorParameter, q::UnscaledVectorParameter) = ($op)(p.value, q.value) #@eval ($op)(p::UnscaledOrSteadyState, q::UnscaledOrSteadyState) = ($op)(p.value, q.value)
    @eval ($op)(p::UnscaledVectorParameter, x::Integer)            = ($op)(p.value, x) #@eval ($op)(p::UnscaledOrSteadyState, x::Integer)            = ($op)(p.value, x)
    @eval ($op)(p::UnscaledVectorParameter, x::Number)            = ($op)(p.value, x) #@eval ($op)(p::UnscaledOrSteadyState, x::Number)            = ($op)(p.value, x)
    #@eval ($op)(x::Number, p::UnscaledOrSteadyState)            = ($op)(x, p.value)

    @eval ($op)(p::ScaledVectorParameter, q::ScaledVectorParameter) = ($op)(p.scaledvalue, q.scaledvalue)
    @eval ($op)(p::ScaledVectorParameter, x::Integer)            = ($op)(p.scaledvalue, x)
    @eval ($op)(p::ScaledVectorParameter, x::Number)            = ($op)(p.scaledvalue, x)
    @eval ($op)(x::Number, p::ScaledVectorParameter)            = ($op)(x, p.scaledvalue)

    @eval ($op)(p::ScaledVectorParameter, q::UnscaledOrSteadyState) = ($op)(p.scaledvalue, q.value)
    #@eval ($op)(p::UnscaledOrSteadyState, q::ScaledVectorParameter) = ($op)(p.value, q.scaledvalue)
end




# Define scalar functional mappings and comparisons
for f in (:(Base.exp),
          :(Base.log),
          :(Base.transpose),
          :(Base.:-),
          :(Base.:<),
          :(Base.:>),
          :(Base.:<=),
          :(Base.:>=))

    @eval ($f)(p::UnscaledOrSteadyState) = ($f)(p.value)
    @eval ($f)(p::ScaledParameter) = ($f)(p.scaledvalue)

    if f != :(Base.:-)
        @eval ($f)(p::UnscaledOrSteadyState, x::Number) = ($f)(p.value, x)
        @eval ($f)(p::ScaledParameter, x::Number) = ($f)(p.scaledvalue, x)
    end
end

# Define scalar operators on grids
for op in (:(Base.:+),
           :(Base.:-),
           :(Base.:*),
           :(Base.:/))

    @eval ($op)(g::SteadyStateParameterGrid, x::Integer)        = ($op)(g.value, x)
    @eval ($op)(g::SteadyStateParameterGrid, x::Number)         = ($op)(g.value, x)
    @eval ($op)(x::Integer, g::SteadyStateParameterGrid)        = ($op)(x, g.value)
    @eval ($op)(x::Number, g::SteadyStateParameterGrid)         = ($op)(x, g.value)
end

# Define vectorized arithmetic for Unscaled or Steady-State Parameters
for op in (:(Base.:+),
           :(Base.:-),
           :(Base.:*),
           :(Base.:/))

    @eval ($op)(p::UnscaledOrSteadyState, x::Vector)        = ($op)(p.value, x)
    @eval ($op)(p::UnscaledOrSteadyState, x::Matrix)        = ($op)(p.value, x)
    @eval ($op)(x::Vector, p::UnscaledOrSteadyState)        = ($op)(x, p.value)
    @eval ($op)(x::Matrix, p::UnscaledOrSteadyState)        = ($op)(x, p.value)
end

# Overload length, iterate to broadcast works properly
Base.length(p::Parameter) = length(p.value)
Base.iterate(p::Parameter, state=1) = state > length(p.value) ? nothing : (state, state+1)

"""
```
update!(pvec::ParameterVector, values::Vector{S}; change_value_type::Bool = false) where S
```

Update all parameters in `pvec` that are not fixed with
`values`. Length of `values` must equal length of `pvec`.
Function optimized for speed.
"""
function update!(pvec::ParameterVector, values::Vector{S};
                 change_value_type::Bool = false) where S
    # this function is optimised for speed
    @assert length(values) == length(pvec) "Length of input vector (=$(length(values))) must match length of parameter vector (=$(length(pvec)))"

    if change_value_type
        tmp = (x,y) -> parameter(x, y; change_value_type = change_value_type)
        map!(tmp, pvec, pvec, values)
    else
        map!(parameter, pvec, pvec, values)
    end
end

"""
```
update!(pvec::ParameterVector, values::Vector{S},
    indices::BitArray{1}; change_value_type::Bool = false) where S
```

Updates a subset of parameters in `pvec` specified by indices. Assumes `values`
is sorted in the same order as the parameters in `pvec`, ignoring parameters
that are to be left unchanged.

However, `update!` will not overwrite fixed parameters, even if
`indices` has a true in an index corresponding to a fixed parameter.


# Examples
```jldoctest
julia> pvec = ParameterVector{Float64}(undef, 3);
julia> pvec[1] = parameter(:a, 1., (0., 3.), (0., 3.), fixed = false);
julia> pvec[2] = parameter(:b, 1.);
julia> pvec[3] = parameter(:c, 1., (0., 3.), (0., 3.), fixed = false);
julia> values = [2., 2.];
julia> update!(pvec, values, [true, false, true]);
julia> map(x -> x.value, pvec)
3-element Array{Float64,1}:
 2.0
 1.0
 2.0

```

```jldoctest
julia> pvec = ParameterVector{Float64}(undef, 3);
julia> pvec[1] = parameter(:a, 1.);
julia> pvec[2] = parameter(:b, 1.);
julia> pvec[3] = parameter(:c, 1.);
julia> values = [2., 2.];
julia> update!(pvec, values, [true, false, true]);
julia> map(x -> x.value, pvec)
3-element Array{Float64,1}:
 1.0
 1.0
 1.0

```
"""
function update!(pvec::ParameterVector, values::AbstractVector{S}, indices::BitArray{1};
                 change_value_type::Bool = false) where S

    # Are you changing all indices? Or a subset?
    if all(indices)
        current_vals = values
    else
        @assert count(indices) == length(values) "Length of input vector (=$(length(values))) must match number of values in parameter vector that `indices` specified to be changed (=$(count(indices)))"
        # Infer whether we need to declare current_vals as a Vector{<:Real}
        # (e.g. if values are ForwardDiff.Dual types)
        # or if current_vals can be a smaller memory type (e.g. Float64)
        try
            eltype(values)::AbstractFloat
            current_vals = Vector{eltype(values)}(map(x -> x.value, pvec))
        catch
            current_vals = Vector{Real}(map(x -> x.value, pvec))
        end
        current_vals[indices] .= values
    end

    update!(pvec, current_vals; change_value_type = change_value_type)
end

"""
```
update(pvec::ParameterVector, values::Vector{S}) where S
```

Returns a copy of `pvec` where non-fixed parameter values are updated
to `values`. `pvec` remains unchanged. Length of `values` must
equal length of `pvec`.

We define the non-mutating version like this because we need the type stability of map!
"""
update(pvec::ParameterVector, values::Vector{S}) where S = update!(copy(pvec), values)

Distributions.pdf(p::AbstractParameter) = exp(logpdf(p))
# we want the unscaled value for ScaledParameters
Distributions.logpdf(p::Parameter{T,U}) where {T, U} = logpdf(get(p.prior),p.value)

# this function is optimised for speed
function Distributions.logpdf(pvec::ParameterVector{T}) where T
	x = zero(T)
	@inbounds for i = 1:length(pvec)
        if hasprior(pvec[i])
    		x += logpdf(pvec[i])
        end
	end
	x
end

# calculate logpdf at new values, without needing to allocate a temporary array with update
function Distributions.logpdf(pvec::ParameterVector, values::Vector{S}) where S
    @assert length(values) == length(pvec) "Length of input vector (=$(length(values))) must match length of parameter vector (=$(length(pvec)))"

    x = zero(S)
    @inbounds for i = 1:length(pvec)
        if hasprior(pvec[i])
            x += logpdf(parameter(pvec[i], values[i]))
        end
    end
    x
end

Distributions.pdf(pvec::ParameterVector{T}) where T  = exp(logpdf(pvec))
Distributions.pdf(pvec::ParameterVector, values::Vector{S}) where S = exp(logpdf(pvec, values))

"""
```
Distributions.rand(p::Vector{AbstractParameter{Float64}})
```

Generate a draw from the prior of each parameter in `p`.
"""
function Distributions.rand(p::Vector{AbstractParameter{Float64}})
    draw = zeros(length(p))
    for (i, para) in enumerate(p)
        draw[i] = if para.fixed
            para.value
        else
            # Resample until all prior draws are within the value bounds
            prio = rand(para.prior.value)
            while !(para.valuebounds[1] < prio < para.valuebounds[2])
                prio = rand(para.prior.value)
            end
            prio
        end
    end
    return draw
end

"""
```
Distributions.rand(p::Vector{AbstractParameter{Float64}}, n::Int)
```

Generate `n` draws from the priors of each parameter in `p`.This returns a matrix of size
`(length(p),n)`, where each column is a sample.
"""
function Distributions.rand(p::Vector{AbstractParameter{Float64}}, n::Int)
    priorsim = zeros(length(p), n)
    for i in 1:n
        priorsim[:, i] = rand(p)
    end
    return priorsim
end

"""
```
moments(θ::Parameter)
```

If θ's prior is a `RootInverseGamma`, τ and ν. Otherwise, returns the mean
and standard deviation of the prior. If θ is fixed, returns `(θ.value, 0.0)`.
"""
function moments(θ::Parameter)
    if θ.fixed
        return θ.value, 0.0
    else
        prior = get(θ.prior)
        if isa(prior, RootInverseGamma)
            return prior.τ, prior.ν
        else
            return mean(prior), std(prior)
        end
    end
end

function describe_prior(param::Parameter)
    if param.fixed
        return "fixed at " * string(param.value)

    elseif !param.fixed && !isnull(param.prior)
        (prior_mean, prior_std) = moments(param)

        prior_dist = string(typeof(get(param.prior)))
        prior_dist = replace(prior_dist, "Distributions." => "")
        prior_dist = replace(prior_dist, "DSGE." => "")
        prior_dist = replace(prior_dist, "{Float64}" => "")

        mom1, mom2 = if isa(prior, RootInverseGamma)
            "tau", "nu"
        else
            "mu", "sigma"
        end

        return prior_dist * "(" * mom1 * "=" * string(round(prior_mean, digits=4)) * ", " *
                                  mom2 * "=" * string(round(prior_std, digits=4)) * ")"

    else
        error("Parameter must either be fixed or have non-null prior: " * string(param.key))
    end
end
