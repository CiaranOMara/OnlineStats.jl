"""
```julia
LinReg(p)
LinReg(p, λ)
```
Create a linear regression object with `p` predictors and optional ridge (L2-regularization)
parameter `λ`.
### Example
```julia
x = randn(1000, 5)
y = x * linspace(-1, 1, 5) + randn(1000)
o = LinReg(5)
s = Series(o)
fit!(s, x, y)
coef(o)
predict(o, x)
coeftable(o)
vcov(o)
confint(o)
```
"""
mutable struct LinReg <: OnlineStat{(1,0), 1, EqualWeight}
    β::VecF
    A::MatF
    S::MatF
    nobs::Int
    λ::Float64
    function LinReg(p::Integer, λ::Float64 = 0.0)
        d = p + 1
        new(zeros(p), zeros(d, d), zeros(d, d), 0, λ)
    end
end
Base.show(io::IO, o::LinReg) = print(io, "LinReg: β($(o.λ)) = $(coef(o)')")
nobs(o::LinReg) = o.nobs

function matviews(o::LinReg)
    p = length(o.β)
    @views o.A[1:p, 1:p], o.A[1:p, end]
end

function fit!(o::LinReg, x::VectorOb, y::Real, γ::Float64)
    xtx, xty = matviews(o)
    smooth_syr!(xtx, x, γ)
    smooth!(xty, x .* y, γ)
    o.A[end] = smooth(o.A[end], y * y, γ)
    o.nobs += 1
end

function _value(o::LinReg)
    copy!(o.S, o.A)
    p = length(o.β)
    if o.λ != 0
        for i in 1:p
            o.S[i, i] += o.λ
        end
    end
    SweepOperator.sweep!(o.S, 1:p)
    copy!(o.β, o.S[1:p, end])
    o.β
end

coef(o::LinReg) = value(o)
predict(o::LinReg, x::AMat) = x * coef(o)
mse(o::LinReg) = (coef(o); o.S[end] * nobs(o) / (nobs(o) - length(o.β)))
# function coeftable(o::LinReg)
#     β = coef(o)
#     p = length(β)
#     se = stderr(o)
#     ts = β ./ se
#     CoefTable(
#         [β se ts Ds.ccdf(Ds.FDist(1, nobs(o) - p), abs2.(ts))],
#         ["Estimate", "Std.Error", "t value", "Pr(>|t|)"],
#         ["x$i" for i in 1:p],
#         4
#     )
# end
# function confint(o::LinReg, level::Real = 0.95)
#     β = coef(o)
#     mult = stderr(o) * quantile(Ds.TDist(nobs(o) - length(β) - 1), (1 - level) / 2)
#     hcat(β, β) + mult * [1. -1.]
# end
function vcov(o::LinReg)
    coef(o)
    p = length(o.β)
    -mse(o) * o.S[1:p, 1:p] / nobs(o)
 end
stderr(o::LinReg) = sqrt.(diag(vcov(o)))

function Base.merge!(o1::LinReg, o2::LinReg, γ::Float64)
    @assert o1.λ == o2.λ
    @assert length(o1.β) == length(o2.β)
    smooth!(o1.A, o2.A, γ)
    o1.nobs += o2.nobs
    coef(o1)
    o1
end
