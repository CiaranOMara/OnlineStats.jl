"""
    ML.FeatureExtractor()

Type for extracting feature vectors from continuous and discrete variables.  Under the hood,
each variable is tracked by one of the following:

- `ML.Numerical()`
- `ML.Categorical()`
- `ML.Ignored()`

# Example 

    o = ML.FeatureExtractor()
    x = [randn(100) rand('a':'d', 100) rand(Date(2010):Date(2011), 100)]
    series(x, o)
    o.dict
"""
module ML

import ..Variance
import ..Unique
import NamedTuples
import OnlineStatsBase: ExactStat, VectorOb
import LearnBase: fit!, value, transform
import DataStructures: SortedDict
export Numerical, Categorical

abstract type AbstractMLColumn <: ExactStat{0} end
fit!(o::AbstractMLColumn, y, γ::Number) = fit!(o.stat, y, γ)
Base.merge!(o::AbstractMLColumn, o2::AbstractMLColumn, γ) = merge!(o.stat, o2.stat, γ)

#-----------------------------------------------------------------------# Numerical
"""
    Numerical()

Track a numerical variable.  Can be used to standardize future observations.
"""
struct Numerical <: AbstractMLColumn  
    stat::Variance
end
Numerical() = Numerical(Variance())
width(o::Numerical) = 1
value(o::Numerical) = (mean(o.stat), std(o.stat))
Base.show(io::IO, o::Numerical) = print(io, "📈 : $(round.(value(o), 4))")

#-----------------------------------------------------------------------# Categorical
"""
    Categorical(T::Type)

Track a categorical variable.  Can be used to create one-hot vectors of future observations.
"""
struct Categorical{T} <: AbstractMLColumn
    stat::Unique{T} 
end
Categorical(T::Type = Any) = Categorical(Unique(T))
width(o::Categorical) = min(0, length(o.stat) - 1)
value(o::Categorical) = value(o.stat)
Base.show(io::IO, o::Categorical) = print(io, "📊 : $(value(o.stat))")

#-----------------------------------------------------------------------# Ignored 
struct Ignored <: AbstractMLColumn end
width(o::Ignored) = 0
value(o::Ignored) = nothing 
fit!(o::Ignored, y, γ::Number) = o
Base.show(io::IO, o::Ignored) = print(io, "Ignored")

#-----------------------------------------------------------------------# FeatureExtractor
"""
    ML.FeatureExtractor(spec)

Track any combination of [`Numerical`](@ref) and [`Categorical`](@ref) features.  The `spec`
should be an example collection (e.g. first row of data) or a collection of data types (schema).

# Example 

    ML.FeatureExtractor([Float64, Bool, String])  # schema
    
    series(randn(100, 3), ML.FeatureExtractor(rand(3)))

    using NamedTuples
    ML.FeatureExtractor(@NT(x=Float64, y=String))  # example row
"""
mutable struct FeatureExtractor{T <: Tuple} <: ExactStat{1}
    colnames::Vector{Symbol}
    features::T
    nobs::Int
end

FeatureExtractor(c::Vector{Symbol}, hints...) = FeatureExtractor(c, make_feature.(hints), 0)
FeatureExtractor(hints::VectorOb) = FeatureExtractor(colnames(hints), hints...)

colnames(y::NamedTuples.NamedTuple) = keys(y)
colnames(y::VectorOb) = [Symbol("x$i") for i in 1:length(y)]

const StringLike = Union{AbstractString, Char, Symbol}
make_feature(val) = Ignored() 
make_feature(val::AbstractMLColumn) = val
make_feature(val::Type{<:Number}) = Numerical() 
make_feature(val::Type{T}) where {T<:StringLike} = Categorical(T)
make_feature(val::Number) = Numerical()
make_feature(val::T) where {T<:StringLike} = Categorical(T)


FeatureExtractor(s::String) = FeatureExtractor(s, fill("a", length(s)))
function FeatureExtractor(s::String, y::VectorOb)
    out = []
    for (si, T) in zip(s, typeof.(y))
        if si == 'n'
            push!(out, Numerical())
        elseif si == 'c'
            push!(out, Categorical(T))
        elseif si == '-'
            push!(out, Ignored())
        else
            error("must be 'n' (Numerical), 'c' (Categorical), or '-' (Ignored)")
        end
    end
    FeatureExtractor(colnames(y), out...)
end




function Base.show(io::IO, o::FeatureExtractor)
    print(io, "FeatureExtractor:")
    d = maximum(length.(string.(o.colnames))) + 1
    for (colname, feat) in zip(o.colnames, o.features)
        print(io, "\n  > $colname: ")
        for i in 1:(d - length(string(colname)))
            print(io, " ")
        end
        print(io, feat)
    end
end


width(o::FeatureExtractor) = sum(width, o.features)

function fit!(o::FeatureExtractor, y::VectorOb, γ)
    for (oi, yi) in zip(o.features, y)
        fit!(oi, yi, γ)
    end
end





end # module
