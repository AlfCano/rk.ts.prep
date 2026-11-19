# rk.ts.prep: Time Series Preparation, Imputation, and Diagnostics for RKWard

![Version](https://img.shields.io/badge/Version-0.0.1-blue.svg)
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
![RKWard](https://img.shields.io/badge/Platform-RKWard-green)
[![R Linter](https://github.com/AlfCano/rk.ts.prep/actions/workflows/lintr.yml/badge.svg)](https://github.com/AlfCano/rk.ts.prep/actions/workflows/lintr.yml)
![AI Gemini](https://img.shields.io/badge/AI-Gemini-4285F4?logo=googlegemini&logoColor=white)

**A Zero-Code GUI Wrapper for `imputeTS`, `tseries`, and `forecast` Diagnostics bringing Professional Time Series Preprocessing to RKWard**

`rk.ts.prep` is the foundational first block of the RKWard Time Series & Forecasting suite (designed to seamlessly complement [`rk.forecast`](https://github.com/AlfCano/rk.forecast)). Before fitting ARIMA or Exponential Smoothing models, real-world business data often suffers from missing gaps, unverified seasonality, or non-stationarity. This plugin provides a clean point-and-click workflow to clean, impute, decompose, and statistically diagnose time series—all without writing a single line of R code.

---

## 🌟 Key Features

*   **Smart `ts` Object Builder:** Convert raw spreadsheet columns into structured R time series (`ts`) objects with standard (Monthly, Quarterly, Weekly, Business Week) or custom frequencies, and optionally trim leading/trailing missing values.
*   **State-of-the-Art Imputation (`imputeTS`):** Fill gaps using Linear/Spline interpolation, Kalman Smoothing (`na_kalman`), Seasonal Decomposition (`na_seadec`), or LOCF—surpassing basic spreadsheet or legacy GUI tools.
*   **Visual Gap Inspection:** Automatically highlights imputed observations in red directly on the `ggplot2` time series curve (`ggplot_na_imputations`) or visualizes missing data distributions (`ggplot_na_distribution`).
*   **Classical & STL Decomposition:** Break series into Trend, Seasonal, and Remainder components using robust LOESS (`stl`) or Classical (Additive/Multiplicative) methods. Computes **Trend & Seasonal Strength (%)** metrics and exports Seasonally Adjusted (`seasadj`) series.
*   **Interactive Box-Jenkins Diagnostics:** Test log transformations, regular differencing ($d$), and seasonal differencing ($D$) in real time with `ggtsdisplay` (Series + ACF + PACF).
*   **Executive Hypothesis Testing:** Runs Ljung-Box, Augmented Dickey-Fuller (ADF), and KPSS tests simultaneously, presenting results in a clean HTML table with **plain-English interpretations**.
*   **Multilingual Ready:** Prepared for English, Spanish, French, German, and Portuguese (Brazil).

---

## What's New in Version 0.0.1

*   **Initial Release:** Introduces 3 sequential preparation tools nested cleanly under `Analysis > Time Series > Time Series Preparation`.
*   **Live Previews & Safe Output:** Real-time `ggplot2` previews across all dialogs, pixel/DPI control over `rk.graph.on()`, and clean workspace saving with emptied plot environments.

---

## ⚙️ Prerequisites

You must have [RKWard](https://rkward.kde.org/) installed along with the following R packages:

```R
install.packages(c("imputeTS", "forecast", "tseries", "ggplot2"))
```

---

## 🚀 Installation

You can install this plugin directly from GitHub or R-Universe inside your RKWard console:

```R
# From R-Universe (Recommended)
install.packages('rk.ts.prep', repos = c('https://alfcano.r-universe.dev', 'https://cloud.r-project.org'))

# Or directly from GitHub
library("remotes")
install_github("AlfCano/rk.ts.prep")
```

Once installed, restart RKWard to ensure the new menu entries under **Analysis > Time Series** appear correctly.

---

## 🛠️ Usage Workflow

This plugin adds three sequential dialogs under **Analysis > Time Series > Time Series Preparation**:

### 1. Define Series & Impute Data
*Turn messy spreadsheet columns into clean time series.*
Select your `data.frame` and numeric column, set the frequency and start period, and choose an imputation algorithm (e.g., Kalman Smoothing). Preview the exact imputed points in red and save the resulting `ts` object (`ts_clean`).

### 2. Decomposition (Classical & STL)
*Uncover hidden trends, seasonal patterns, and outliers.*
Select any `ts` object from your workspace. Choose STL (with optional robust outlier resistance) or Classical Additive/Multiplicative decomposition. Review the Trend and Seasonal Strength percentages and optionally export the seasonally adjusted series (`ts_seas_adj`).

### 3. Diagnostics (ACF/PACF, Ljung-Box, ADF)
*Check stationarity and autocorrelation before ARIMA modeling.*
Experiment with `log()`, regular differences ($d$), and seasonal differences ($D$) while watching the 3-panel Series + ACF + PACF plot update live. Confirm stationarity and autocorrelation via the automated Ljung-Box, ADF, and KPSS interpretation table.

---

## 📊 Real-World Case Study: Preparing & Diagnosing Demand Data

Let's simulate a real business scenario where historical monthly passenger records have 8 missing months, and prepare the series for Box-Jenkins (ARIMA) modeling.

### Step 1: Create Test Data with Missing Gaps
Open the **R Console** in RKWard and run:
```R
df_test <- data.frame(passengers = as.numeric(AirPassengers))
# Simulate 8 missing months (isolated and consecutive gaps)
df_test$passengers[c(15, 16, 40, 62, 63, 64, 100, 125)] <- NA
```

### Step 2: Define Series & Impute Missing Values
Go to **Analysis > Time Series > Time Series Preparation > 1. Define Series & Impute Data**.
1. **Data & Structure:** Select `df_test` and `passengers`. Set Frequency to `Monthly (12)`, Start Year to `1949`, and Start Period to `1`.
2. **Imputation (NAs):** Select **Kalman Smoothing (na_kalman - StructTS)**.
3. Click **Preview** to inspect the blue known observations and red diamond imputed points, then click **Submit**.
   *👉 Output confirms `NAs_Before: 8` → `NAs_After: 0`, saving `ts_clean` to your workspace.*

### Step 3: Decompose the Clean Series
Go to **Analysis > Time Series > Time Series Preparation > 2. Decomposition (Classical & STL)**.
1. Select `ts_clean` and leave **STL (Recommended)** with `Robust fitting` checked.
2. Click **Submit**.
   *👉 Look at **Component Strength Metrics**: `Trend Strength: 95%` and `Seasonal Strength: 68%`. Notice in the bottom `remainder` panel how residual spikes grow larger in later years—a classic visual clue that variance is multiplicative and a log transformation is warranted.*

### Step 4: Stationarity & Autocorrelation Diagnostics
Go to **Analysis > Time Series > Time Series Preparation > 3. Diagnostics (ACF/PACF, Ljung-Box, ADF)**.
1. Select `ts_clean`. First check **Preview** with `d = 0, D = 0`: slow ACF decay indicates non-stationarity.
2. Now check **Apply Log Transformation (log)**, set Regular Differencing **d = 1**, and Seasonal Differencing **D = 1**.
3. Click **Submit**.

**What to look for in the Output:**
*   **Hypothesis Tests Table:**
    *   **ADF** ($p = 0.01$): *Stationary (Reject unit root)*
    *   **KPSS** ($p = 0.10$): *Stationary (Cannot reject stationarity)*
    *   **Ljung-Box** ($Q^* = 71.98$, $p = 0.00$): *Autocorrelation detected (Not White Noise)*
*   **ACF / PACF Display:** Clear significant spikes stand out at **Lag 1** and **Lag 12**—visually pointing straight toward the classic Box-Jenkins Airline Model: **`ARIMA(0,1,1)(0,1,1)[12]`**.

---

## 🗣️ Communicating with Numbers (Translating Output to Business)

> *"Before forecasting demand, we audited 12 years of monthly records and identified 8 missing entries. Using Kalman Smoothing, we reconstructed those gaps without distorting seasonal peaks. Structural decomposition revealed that 95% of demand movement is driven by long-term growth and 68% by strong annual seasonality. After stabilizing growth and seasonal cycles, formal stationarity tests confirmed the series is clean and carries genuine predictive autocorrelation—giving our forecasting models a verified, reliable foundation."*

---

## 🌍 Internationalization (i18n)

The graphical interface automatically adapts to your RKWard language settings. Currently supported languages:
*   🇺🇸 English (Default)
*   🇪🇸 Spanish (Español)
*   🇫🇷 French (Français)
*   🇩🇪 German (Deutsch)
*   🇧🇷 Portuguese (Português do Brasil)

---

## 📝 License and Author

**Author:** Alfonso Cano ([@AlfCano](https://github.com/AlfCano))  
**Email:** alfonso.cano@correo.buap.mx  
*   **Assisted by:** Gemini, a large language model from Google.
*   **License:** GPL (>= 3)

This project is licensed under the **GPL (>= 3)** License.
