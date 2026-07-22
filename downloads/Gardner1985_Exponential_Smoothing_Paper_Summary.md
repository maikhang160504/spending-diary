# Exponential Smoothing: The State of the Art - Reference Summary

## IEEE Full Citation
[18] E. S. Gardner Jr., "Exponential smoothing: The state of the art," *Journal of Forecasting*, vol. 4, no. 1, pp. 1–28, 1985. DOI: 10.1002/for.3980040103.
[18b] E. S. Gardner Jr., "Exponential smoothing: The state of the art — Part II," *International Journal of Forecasting*, vol. 22, no. 4, pp. 637–666, 2006. DOI: 10.1016/j.ijforecast.2006.03.009.

## Abstract & Mathematical Foundation
Exponential smoothing methods, originated by Robert G. Brown (1956) and Charles C. Holt (1957), represent a foundational class of time series forecasting algorithms that assign exponentially decreasing weights to older historical observations. Unlike simple moving averages that treat all observations equally within a fixed window and suffer from sensitivity to outliers, Single Exponential Smoothing (SES) provides a recursive formulation:
$$F_{t+1} = \alpha Y_t + (1 - \alpha) F_t$$
where:
- $Y_t$ is the actual observed value at time step $t$.
- $F_t$ is the forecasted value for time step $t$ (derived from $F_t = \alpha Y_{t-1} + (1 - \alpha) F_{t-1}$).
- $\alpha \in (0, 1)$ is the smoothing parameter (weight). A higher $\alpha$ makes the model more responsive to recent shifts, while a lower $\alpha$ provides greater damping against random fluctuations and temporary outliers.

## Application in Spending Diary Thesis (Section 2.8)
In the **Saving Trend & Budget Suggestion Report (`SavingTrendReportScreen` / `AiService`)**, projecting future monthly budget limits must balance recent user spending habits against temporary anomalies (e.g., one-off high-ticket purchases). Spending Diary utilizes Single Exponential Smoothing with an empirically optimized parameter $\alpha = 0.35$:
$$F_{t+1} = 0.35 Y_t + 0.65 F_t$$
This ensures the AI budget suggestion adapts smoothly to genuine changes in personal lifestyle while suppressing transient spikes.
