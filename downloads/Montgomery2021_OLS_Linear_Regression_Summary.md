# Introduction to Linear Regression Analysis & OLS - Reference Summary

## IEEE Full Citation
[19] D. C. Montgomery, E. A. Peck, and G. G. Vining, *Introduction to Linear Regression Analysis*, 6th ed., Hoboken, NJ, USA: John Wiley & Sons, 2021. ISBN: 978-1-119-57872-7.

## Abstract & Mathematical Foundation
Ordinary Least Squares (OLS) linear regression is a statistical technique used to estimate the linear relationship between a dependent variable $y$ and one or more independent variables $x$ by minimizing the sum of squared residuals between observed values and model predictions. For simple linear regression $\hat{y} = \beta_0 + \beta_1 x$, the slope coefficient $\beta_1$ measures the rate of change and trend direction, derived analytically as:
$$\beta_1 = \frac{\sum_{i=1}^{n} (x_i - \bar{x})(y_i - \bar{y})}{\sum_{i=1}^{n} (x_i - \bar{x})^2} = \frac{\text{Cov}(x, y)}{\text{Var}(x)}$$
and the intercept $\beta_0 = \bar{y} - \beta_1 \bar{x}$.

## Application in Spending Diary Thesis (Section 2.8)
In the **Saving Trend Report (`SavingTrendReportScreen`)**, assessing financial health requires identifying whether a user's savings margin is growing or deteriorating over sequential cycles. Spending Diary computes the savings ratio $R_i$ for each period $i \in \{1, 2, \dots, n\}$:
$$R_i = \frac{\text{Total Income}_i - \text{Total Expense}_i}{\text{Total Income}_i}$$
Applying OLS over $(i, R_i)$ yields the trajectory slope $\beta_1$:
- If $\beta_1 > 0$: Indicates positive financial growth and expanding savings habits.
- If $\beta_1 < 0$: Triggers early warnings for deteriorating budget control and potential overspending.
