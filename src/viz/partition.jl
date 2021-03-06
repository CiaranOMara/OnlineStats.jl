

# abstract type AbstractPartition{N} <: OnlineStat{N} end

# nobs(o::AbstractPartition) = isempty(o.parts) ? 0 : sum(nobs, o.parts)

# #-----------------------------------------------------------------------# Part 
# """
#     Part(stat, a, b)

# `stat` summarizes a Y variable over an X variable's range `a` to `b`.
# """
# mutable struct Part{T, O <: OnlineStat} <: OnlineStat{XY} 
#     stat::O 
#     a::T
#     b::T 
# end
# # Part(o::O, ab::T) where {O<:OnlineStat, T} = Part{T,O}(o, ab, ab)
# nobs(o::Part) = nobs(o.stat)
# Base.show(io::IO, o::Part) = print(io, "Part $(o.a) to $(o.b) | $(o.stat)")
# function _merge!(o::Part, o2::Part)
#     _merge!(o.stat, o2.stat)
#     o.a = min(o.a, o2.a)
#     o.b = max(o.b, o2.b)
#     o
# end
# Base.in(x, o::Part) = (o.a ≤ x ≤ o.b)
# Base.isless(o::Part, o2::Part) = o.b < o2.a
# value(o::Part) = value(o.stat)

# midpoint(o::Part{<:Number}) = middle(o.a, o.b)

# function midpoint(o::Part) 
#     if o.a == o.b 
#         return o.a 
#     else
#         return (o.a:o.b)[round(Int, length(o.a:o.b) / 2)]
#     end
# end

# midpoint(o::Part{<:TimeType}) = o.a + fld(o.b - o.a, 2)

# width(o::Part) = o.b - o.a

# isfull(o::Part{Int}) = (nobs(o) == o.b - o.a + 1)

# function _fit!(p::Part, xy)
#     x, y = xy
#     x in p || error("$x ∉ [$(o.a), $(o.b)]")
#     _fit!(p.stat, y)
# end

#-----------------------------------------------------------------------# Partition 
"""
    Partition(stat, nparts=100; method=:equal)

Split a data stream into `nparts` where each part is summarized by `stat`.  

- `method = :equal`
    - Maintain roughly the same nobs in each part.

# Example 

    o = Partition(Extrema())
    fit!(o, cumsum(randn(10^5)))

    using Plots
    plot(o)
"""
mutable struct Partition{T, O <: OnlineStat{T}, P <: Part{ClosedInterval{Int}, O}} <: OnlineStat{T}
    parts::Vector{P}
    b::Int
    init::O
    method::Symbol
    n::Int
end
function Partition(o::O, b::Int=100; method=:equal) where {O <: OnlineStat}
    Partition(Part{ClosedInterval{Int}, O}[], b, o, method, 0)
end

function _fit!(o::Partition, y)
    isempty(o.parts) && push!(o.parts, Part(copy(o.init), ClosedInterval(1, 1)))
    lastpart = last(o.parts)
    n = o.n += 1
    if n ∈ lastpart 
        _fit!(lastpart, n => y)
    else
        stat = fit!(copy(o.init), y)
        push!(o.parts, Part(stat, ClosedInterval(n, n + nobs(lastpart) - 1)))
    end
    length(o.parts) > o.b && isfull(last(o.parts)) && merge_next!(o.parts, o.method)
end

isfull(p::Part{<:ClosedInterval}) = nobs(p) == p.domain.last - p.domain.first + 1

function merge_next!(parts::Vector{<:Part}, method)
    if method === :equal
        n = nobs(first(parts))
        i = 1
        for (j, p) in enumerate(parts)
            nobs(p) < n && (i = j; break;)
        end
        merge!(parts[i], parts[i + 1])
        deleteat!(parts, i + 1)
    elseif method === :oldest_first
        ind = 1
        error("TODO")
    else
        error("Method is not recognized")
    end
end

# Assumes `a` goes before `b`
function _merge!(a::Partition, b::Partition)
    n = nobs(a)
    a.n += b.n
    for p in b.parts
        push!(a.parts, Part(copy(p.stat), ClosedInterval(p.domain.first + n, p.domain.last + n)))
    end
    while length(a.parts) > a.b
        merge_next!(a.parts, a.method)
    end
    a
end


#-----------------------------------------------------------------------# IndexedPartition
"""
    IndexedPartition(T, stat, b=100)

Summarize data with `stat` over a partition of size `b` where the data is indexed by a 
variable of type `T`.

# Example 

    o = IndexedPartition(Float64, Hist(10))
    fit!(o, eachrow(randn(10^4, 2)))

    using Plots 
    plot(o)
"""
mutable struct IndexedPartition{I, T, O <: OnlineStat{T}, P <: Part{ClosedInterval{I}, O}} <: OnlineStat{TwoThings}
    parts::Vector{P}
    b::Int
    init::O
    method::Symbol
    n::Int
end
function IndexedPartition(I::Type, o::O, b::Int=100; method=:weighted_nearest) where {T, O<:OnlineStat{T}}
    IndexedPartition(Part{ClosedInterval{I}, O}[], b, o, method, 0)
end

function _fit!(o::IndexedPartition{I,T,O}, xy) where {I,T,O}
    x, y = xy
    n = o.n += 1
    isempty(o.parts) && push!(o.parts, Part(copy(o.init), ClosedInterval(I(x), I(x))))
    i = findfirst(p -> x in p, o.parts)
    if isnothing(i) 
        push!(o.parts, Part(fit!(copy(o.init), y), ClosedInterval(x, x)))
    else 
        _fit!(o.parts[i], xy)
    end
    length(o.parts) > o.b && indexed_merge_next!(sort!(o.parts), o.method)
end

function indexed_merge_next!(parts::Vector{<:Part}, method)
    if method === :weighted_nearest
        diffs = [diff(a, b) * middle(nobs(a), nobs(b)) for (a, b) in neighbors(parts)]
        _, i = findmin(diffs)
        merge!(parts[i], parts[i + 1])
        deleteat!(parts, i + 1)
    else
        error("method not recognized")
    end
end

function _merge!(o::IndexedPartition, o2::IndexedPartition)
    # If there's any overlap, merge
    for p2 in o2.parts 
        pushpart = true
        for p in o.parts 
            if (p2.domain.first ∈ p) || (p2.domain.last ∈ p)
                pushpart = false
                merge!(p, p2) 
                break               
            end
        end
        pushpart && push!(o.parts, p2)
    end
    # merge parts that overlap 
    for i in reverse(2:length(o.parts))
        p1, p2 = o.parts[i-1], o.parts[i]
        if p1.domain.first > p2.domain.last
            # info("hey I deleted something at $i")
            merge!(p1, p2)
            deleteat!(o.parts, i)
        end
    end
    # merge until there's b left
    sort!(o.parts)
    while length(o.parts) > o.b 
        indexed_merge_next!(o.parts, o.method)
    end
    o
end
