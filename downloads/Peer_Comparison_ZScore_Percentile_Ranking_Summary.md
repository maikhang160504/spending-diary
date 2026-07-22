# Peer Effects in Personal Finance & Radar Chart Normalization - Reference Summary

## IEEE Full Citation
[20] P. D'Astous and K. Gleason, "Peer effects in personal finance," *Journal of Economic Behavior & Organization*, vol. 157, pp. 583–602, 2019. DOI: 10.1016/j.jebo.2018.10.016.
[21] M. E. Newman, "Power laws, Pareto distributions and Zipf's law," *Contemporary Physics*, vol. 46, no. 5, pp. 323–351, 2005. DOI: 10.1080/00107510500052444.

## Abstract & Mathematical Foundation
Behavioral economics demonstrates that personal financial behaviors—such as consumption allocation, debt accumulation, and saving tendencies—are significantly influenced by peer group comparisons and relative financial standing (`peer effects`). To provide meaningful benchmarking across heterogeneous income levels and demographic profiles, financial analytics engines utilize standard Z-score normalization and cumulative distribution percentile ranking:
$$Z_{u,k} = \frac{E_{u,k} - \mu_k}{\sigma_k}$$
where $E_{u,k}$ is user $u$'s spending in category $k$, while $\mu_k$ and $\sigma_k$ are the mean and standard deviation of peer group spending in that category. The relative percentile score is obtained via the normal cumulative distribution function $\Phi(Z_{u,k}) \times 100\%$.

## Application in Spending Diary Thesis (Section 2.8)
In the **Peer Comparison Report (`PeerCompareReportScreen`)**, Spending Diary visualizes multi-criteria spending behavior across major categories (Food, Housing, Transport, Shopping, Entertainment) using a normalized multi-dimensional Radar Chart. By transforming raw spending figures into standard Z-scores and percentile ranks relative to demographic cohorts, the application highlights structural overspending (e.g., when a user's dining expense falls in the 90th percentile of their income peer group) and generates actionable AI financial recommendations.
