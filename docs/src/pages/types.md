# What Can OnlineStats Do?

| Statistic/Model                        | OnlineStat                 |
|:---------------------------------------|:---------------------------|
| **Univariate Statistics:**             |                            |
| mean                                   | [`Mean`](@ref)             |
| variance                               | [`Variance`](@ref)         |
| quantiles                              | [`Quantiles`](@ref)        |
| quantiles via Online MM                | [`QuantileMM`](@ref)       |
| max and min                            | [`Extrema`](@ref)          |
| skewness and kurtosis                  | [`Moments`](@ref)          |
| sum                                    | [`Sum`](@ref)              |
| difference                             | [`Diff`](@ref)             |
| histogram                              | [`OHistogram`](@ref)       |
| approximate order statistics           | [`OrderStatistics`](@ref)  |
| **Multivariate Analysis:**             |                            |
| covariance matrix                      | [`CovMatrix`](@ref)        |
| k-means clustering                     | [`KMeans`](@ref)           |
| multiple univariate statistics         | [`MV{<:OnlineStat}`](@ref) |
| **Density Estimation:**                |                            |
| Beta                                   | [`FitBeta`](@ref)          |
| Categorical                            | [`FitCategorical`](@ref)   |
| Cauchy                                 | [`FitCauchy`](@ref)        |
| Gamma                                  | [`FitGamma`](@ref)         |
| LogNormal                              | [`FitLogNormal`](@ref)     |
| Normal                                 | [`FitNormal`](@ref)        |
| Multinomial                            | [`FitMultinomial`](@ref)   |
| MvNormal                               | [`FitMvNormal`](@ref)      |
| **Statistical Learning:**              |                            |
| GLMs with regularization               | [`StatLearn`](@ref)        |
| Linear (also ridge) regression         | [`LinReg`](@ref)           |
| **Other:**                             |                            |
| Bootstrapping                          | [`Bootstrap`](@ref)        |
| approximate count of distinct elements | [`HyperLogLog`](@ref)      |
| Reservoir Sampling                     | [`ReservoirSample`](@ref)  |
