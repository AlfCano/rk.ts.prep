local({
  # =========================================================================================
  # 1. Setup and Metadata
  # =========================================================================================
  require(rkwarddev)
  rkwarddev.required("0.10-3")

  plugin_name <- "rk.ts.prep"

  package_about <- rk.XML.about(
    name = plugin_name,
    author = person(
      given = "Alfonso",
      family = "Cano",
      email = "alfonso.cano@correo.buap.mx",
      role = c("aut", "cre")
    ),
    about = list(
      desc = "Time Series Preparation, Imputation (imputeTS), Decomposition (STL/Classical), and Diagnostics (ACF/PACF, ADF, KPSS, Ljung-Box).",
      version = "0.0.1",
      url = "https://github.com/AlfCano/rk.ts.prep",
      license = "GPL (>= 3)"
    )
  )

  dependencies_node <- rk.XML.dependencies(
    dependencies = list(R.min = "4.0.0"),
    package = list(
      c(name = "imputeTS"),
      c(name = "forecast"),
      c(name = "tseries"),
      c(name = "ggplot2")
    )
  )

  # MISMA JERARQUÍA EXACTA QUE rk.forecast (Regla de Oro #2: Case-Sensitive)
  h_ts <- list("analysis", "time_series", "Time Series Preparation")


  # Global JavaScript Helper Functions (Regla de Oro #8)
  js_helpers <- "
    function cleanStr(val) {
        if(!val) return '';
        return val.replace(/'/g, \"\\\\'\").replace(/\"/g, '\\\\\"');
    }

    function parseVar(fullPath) {
        if (!fullPath) return '';
        var raw_col = '';
        if (fullPath.indexOf('[[') > -1) {
            var parts = fullPath.split('[[');
            var inner = parts[1].replace(']]', '');
            raw_col = inner.replace(/[\"']/g, '');
        } else if (fullPath.indexOf('$') > -1) {
            raw_col = fullPath.split('$')[1];
        } else {
            raw_col = fullPath;
        }
        return raw_col;
    }
  "

  # =========================================================================================
  # 2. MAIN MODULE: 1. Define Series & Impute Data (imputeTS)
  # =========================================================================================

  # --- UI Elements ---
  prep_vs <- rk.XML.varselector(id.name = "prep_vs")
  prep_df <- rk.XML.varslot("Data Frame", source = "prep_vs", classes = "data.frame", required = TRUE, id.name = "prep_df")
  prep_var <- rk.XML.varslot("Target Variable (Numeric)", source = "prep_vs", classes = c("numeric", "integer"), required = TRUE, id.name = "prep_var")

  prep_freq <- rk.XML.dropdown("Data Frequency (Seasonality)", options = list(
    "Monthly (12)" = list(val = "12", chk = TRUE),
    "Quarterly (4)" = list(val = "4"),
    "Yearly (1)" = list(val = "1"),
    "Weekly (52)" = list(val = "52"),
    "Daily - Business Week (5)" = list(val = "5"),
    "Daily - Full Week (7)" = list(val = "7"),
    "Custom Frequency" = list(val = "custom")
  ), id.name = "prep_freq")

  prep_freq_cust <- rk.XML.spinbox("Custom Frequency (Periods per cycle)", min = 1, max = 1000, initial = 24, real = FALSE, id.name = "prep_freq_cust")
  prep_start_yr <- rk.XML.spinbox("Start Year / Major Cycle", min = 1, max = 3000, initial = 2020, real = FALSE, id.name = "prep_start_yr")
  prep_start_pd <- rk.XML.spinbox("Start Period (e.g., 1 for Jan/Q1)", min = 1, max = 1000, initial = 1, real = FALSE, id.name = "prep_start_pd")

  frm_prep_str <- rk.XML.frame(
    prep_freq, prep_freq_cust,
    rk.XML.row(prep_start_yr, prep_start_pd),
    label = "Time Series Structure"
  )

  # Imputation Options
  prep_imp_method <- rk.XML.radio("Missing Value (NA) Imputation Method", options = list(
    "No imputation (Keep original NAs)" = list(val = "none", chk = TRUE),
    "Linear Interpolation (na_interpolation)" = list(val = "linear"),
    "Spline Interpolation (na_interpolation - spline)" = list(val = "spline"),
    "Kalman Smoothing (na_kalman - StructTS)" = list(val = "kalman"),
    "Seasonal Decomposition + Interpolation (na_seadec)" = list(val = "seadec"),
    "Last Observation Carried Forward (na_locf)" = list(val = "locf")
  ), id.name = "prep_imp_method")

  prep_trim <- rk.XML.cbox("Trim leading and trailing NAs before creating series", value = "1", chk = FALSE, id.name = "prep_trim")
  frm_prep_imp <- rk.XML.frame(prep_imp_method, prep_trim, label = "Missing Data Handling (imputeTS)")

  # Plot Options
  prep_theme <- rk.XML.dropdown("Plot Theme (ggplot2)", options = list(
    "Minimal (Clean business look)" = list(val = "minimal", chk = TRUE),
    "Classic (Scientific)" = list(val = "classic"),
    "Black & White (Grid)" = list(val = "bw")
  ), id.name = "prep_theme")
  prep_plot_main <- rk.XML.input("Main Title (Leave empty for default)", id.name = "prep_plot_main")
  prep_plot_xlab <- rk.XML.input("X-Axis Label (Leave empty for default)", id.name = "prep_plot_xlab")
  prep_plot_ylab <- rk.XML.input("Y-Axis Label (Leave empty for default)", id.name = "prep_plot_ylab")
  frm_prep_plot <- rk.XML.frame(prep_theme, prep_plot_main, prep_plot_xlab, prep_plot_ylab, label = "Plot Customization")

  # Output Options
  prep_save <- rk.XML.saveobj("Save Time Series (ts) object as", initial = "ts_clean", chk = TRUE, id.name = "prep_save")
  prep_plot_w <- rk.XML.spinbox("HTML Plot Width (pixels)", min = 100, max = 5000, initial = 800, real = FALSE, id.name = "prep_plot_w")
  prep_plot_h <- rk.XML.spinbox("HTML Plot Height (pixels)", min = 100, max = 5000, initial = 600, real = FALSE, id.name = "prep_plot_h")
  prep_plot_res <- rk.XML.spinbox("Resolution (DPI)", min = 72, max = 600, initial = 120, real = FALSE, id.name = "prep_plot_res")
  frm_prep_graph <- rk.XML.frame(rk.XML.row(prep_plot_w, prep_plot_h, prep_plot_res), label = "HTML Graphics Size & Resolution")
  prep_plot_save <- rk.XML.saveobj("Save Plot (ggplot2) as", initial = "prep_plot", chk = FALSE, id.name = "prep_plot_save")

  prep_preview <- rk.XML.preview(label = "Preview Series / Imputation Plot")

  # --- UI Logic (Regla de Oro #11: Auto-Focus + string = para dropdown) ---
  cond_freq_cust <- rk.XML.convert(sources = list(string = prep_freq), mode = c(equals = "custom"), id.name = "cond_freq_cust")

  logic_prep <- rk.XML.logic(
    rk.XML.connect(governor = prep_df, get = "available", client = prep_vs, set = "root"),
    cond_freq_cust,
    rk.XML.connect(governor = cond_freq_cust, client = prep_freq_cust, set = "enabled")
  )

  # --- Layout (Regla de Oro #10: Tabbook) ---
  tab_prep <- rk.XML.tabbook(tabs = list(
    "Data & Structure" = rk.XML.col(prep_df, prep_var, frm_prep_str, rk.XML.stretch()),
    "Imputation (NAs)" = rk.XML.col(frm_prep_imp, rk.XML.stretch()),
    "Plot Options" = rk.XML.col(frm_prep_plot, rk.XML.stretch()),
    "Output" = rk.XML.col(
      rk.XML.frame(prep_save, label = "Save Time Series to Workspace"),
      frm_prep_graph,
      rk.XML.frame(prep_plot_save, label = "Save Plot Object"),
      rk.XML.stretch()
    )
  ))

  dialog_prep <- rk.XML.dialog(
    rk.XML.row(
      prep_vs,
      rk.XML.col(tab_prep, prep_preview)
    ),
    label = "1. Define Series & Impute Data"
  )

  # --- JavaScript ---
  js_calc_prep <- "
    var data = getValue('prep_df');
    var target = parseVar(getValue('prep_var'));
    var freq = getValue('prep_freq');
    var freq_val = (freq === 'custom') ? getValue('prep_freq_cust') : freq;
    var yr = getValue('prep_start_yr');
    var pd = getValue('prep_start_pd');
    var trim_na = getValue('prep_trim') === '1';
    var method = getValue('prep_imp_method');

    var theme = getValue('prep_theme');
    var main_tit = cleanStr(getValue('prep_plot_main'));
    var x_tit = cleanStr(getValue('prep_plot_xlab'));
    var y_tit = cleanStr(getValue('prep_plot_ylab'));

    echo('raw_vector <- ' + data + '[[\"' + target + '\"]]\\n');
    if (trim_na) {
        echo('non_na_idx <- which(!is.na(raw_vector))\\n');
        echo('if (length(non_na_idx) > 0) raw_vector <- raw_vector[min(non_na_idx):max(non_na_idx)]\\n');
    }
    echo('ts_raw <- stats::ts(raw_vector, frequency = ' + freq_val + ', start = c(' + yr + ', ' + pd + '))\\n\\n');

    // Regla de Oro #3: Hardcode exacto al 'initial' de prep_save ('ts_clean')
    if (method === 'none') {
        echo('ts_clean <- ts_raw\\n');
    } else {
        echo('if (anyNA(ts_raw)) {\\n');
        if (method === 'linear') {
            echo('  ts_clean <- imputeTS::na_interpolation(ts_raw, option = \"linear\")\\n');
        } else if (method === 'spline') {
            echo('  ts_clean <- imputeTS::na_interpolation(ts_raw, option = \"spline\")\\n');
        } else if (method === 'kalman') {
            echo('  ts_clean <- imputeTS::na_kalman(ts_raw, model = \"StructTS\")\\n');
        } else if (method === 'seadec') {
            echo('  if (frequency(ts_raw) < 2) {\\n');
            echo('    ts_clean <- imputeTS::na_interpolation(ts_raw, option = \"linear\")\\n');
            echo('  } else {\\n');
            echo('    ts_clean <- imputeTS::na_seadec(ts_raw, algorithm = \"interpolation\")\\n');
            echo('  }\\n');
        } else if (method === 'locf') {
            echo('  ts_clean <- imputeTS::na_locf(ts_raw)\\n');
        }
        echo('} else {\\n');
        echo('  ts_clean <- ts_raw\\n');
        echo('}\\n');
    }
    echo('\\n');

    // Plot inteligente dependiendo de si hubo NAs e imputación
    var title_str = (main_tit !== '') ? main_tit : 'Time Series: ' + target;
    echo('if (anyNA(ts_raw) && !anyNA(ts_clean)) {\\n');
    echo('  p <- imputeTS::ggplot_na_imputations(x_with_na = ts_raw, x_with_imputations = ts_clean) +\\n');
    echo('       ggplot2::theme_' + theme + '()\\n');
    echo('} else if (anyNA(ts_raw)) {\\n');
    echo('  p <- imputeTS::ggplot_na_distribution(ts_raw) +\\n');
    echo('       ggplot2::theme_' + theme + '()\\n');
    echo('} else {\\n');
    echo('  p <- ggplot2::autoplot(ts_clean) +\\n');
    echo('       ggplot2::theme_' + theme + '()\\n');
    echo('}\\n');

    echo('p <- p + ggplot2::labs(title = \"' + title_str + '\"');
    if (x_tit !== '') echo(', x = \"' + x_tit + '\"');
    if (y_tit !== '') echo(', y = \"' + y_tit + '\"');
    echo(')\\n\\n');

    echo('prep_summary <- data.frame(\\n');
    echo('  Start = paste(stats::start(ts_clean), collapse = \"-\"),\\n');
    echo('  End = paste(stats::end(ts_clean), collapse = \"-\"),\\n');
    echo('  Frequency = stats::frequency(ts_clean),\\n');
    echo('  Observations = length(ts_clean),\\n');
    echo('  NAs_Before = sum(is.na(ts_raw)),\\n');
    echo('  NAs_After = sum(is.na(ts_clean))\\n');
    echo(')\\n');
  "

  js_print_prep <- "
    var w = getValue('prep_plot_w');
    var h = getValue('prep_plot_h');
    var res = getValue('prep_plot_res');

    if (typeof is_preview !== 'undefined' && is_preview) {
        echo('print(p)\\n');
    }

    if (typeof is_preview === 'undefined' || !is_preview) {
        echo('rk.header(\"1. Time Series Preparation & Imputation\")\\n');

        echo('rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\\n');
        echo('print(p)\\n');
        echo('rk.graph.off()\\n\\n');

        echo('rk.header(\"Series Summary\", level = 3)\\n');
        echo('rk.print(prep_summary)\\n');

        if (getValue('prep_save.active') || getValue('prep_plot_save.active')) { echo('rk.print(\"<hr>\")\\n'); }
        if (getValue('prep_save.active')) {
            echo('rk.print(paste0(\"<b>Time Series (ts) saved as: </b><code>\", \"' + getValue('prep_save') + '\", \"</code><br>\"))\\n');
        }
        if (getValue('prep_plot_save.active')) {
            // Regla de Oro #12: Vaciar entorno de ggplot antes de guardar
            echo('p$plot_env <- emptyenv()\\n');
            echo('prep_plot <- p\\n');
            echo('rk.print(paste0(\"<b>Plot object (ggplot2) saved as: </b><code>\", \"' + getValue('prep_plot_save') + '\", \"</code>\"))\\n');
        }
    }
  "

  # =========================================================================================
  # 3. MODULE 2: 2. Decomposition (Classical & STL)
  # =========================================================================================

  # --- UI Elements ---
  # Sin root en varselector para ver todos los objetos 'ts' del Workspace (ej. ts_clean, AirPassengers)
  dec_vs <- rk.XML.varselector(id.name = "dec_vs")
  dec_ts <- rk.XML.varslot("Time Series Object (ts)", source = "dec_vs", classes = "ts", required = TRUE, id.name = "dec_ts")

  dec_method <- rk.XML.radio("Decomposition Method", options = list(
    "STL (LOESS Seasonal-Trend Decomposition) - Recommended" = list(val = "stl", chk = TRUE),
    "Classical Additive (Trend + Seasonal + Random)" = list(val = "additive"),
    "Classical Multiplicative (Trend * Seasonal * Random)" = list(val = "multiplicative")
  ), id.name = "dec_method")

  dec_stl_periodic <- rk.XML.cbox("Periodic seasonal window (s.window = 'periodic')", value = "TRUE", chk = TRUE, id.name = "dec_stl_periodic")
  dec_stl_swin <- rk.XML.spinbox("Custom s.window (odd integer >= 7)", min = 7, max = 99, initial = 13, real = FALSE, id.name = "dec_stl_swin")
  dec_stl_robust <- rk.XML.cbox("Robust fitting (resistant to outliers)", value = "TRUE", chk = TRUE, id.name = "dec_stl_robust")

  frm_stl_opts <- rk.XML.frame(dec_stl_periodic, dec_stl_swin, dec_stl_robust, label = "STL Specific Options", id.name = "frm_stl_opts")

  # Plot Options
  dec_theme <- rk.XML.dropdown("Plot Theme (ggplot2)", options = list(
    "Minimal (Clean business look)" = list(val = "minimal", chk = TRUE),
    "Classic (Scientific)" = list(val = "classic"),
    "Black & White (Grid)" = list(val = "bw")
  ), id.name = "dec_theme")
  dec_plot_main <- rk.XML.input("Main Title (Leave empty for default)", id.name = "dec_plot_main")
  dec_plot_xlab <- rk.XML.input("X-Axis Label (Leave empty for default)", id.name = "dec_plot_xlab")
  frm_dec_plot <- rk.XML.frame(dec_theme, dec_plot_main, dec_plot_xlab, label = "Plot Customization")

  # Output Options
  dec_save <- rk.XML.saveobj("Save decomposed object as", initial = "ts_decomp", chk = FALSE, id.name = "dec_save")
  dec_save_adj <- rk.XML.saveobj("Save Seasonally Adjusted series (ts) as", initial = "ts_seas_adj", chk = FALSE, id.name = "dec_save_adj")

  dec_plot_w <- rk.XML.spinbox("HTML Plot Width (pixels)", min = 100, max = 5000, initial = 800, real = FALSE, id.name = "dec_plot_w")
  dec_plot_h <- rk.XML.spinbox("HTML Plot Height (pixels)", min = 100, max = 5000, initial = 650, real = FALSE, id.name = "dec_plot_h")
  dec_plot_res <- rk.XML.spinbox("Resolution (DPI)", min = 72, max = 600, initial = 120, real = FALSE, id.name = "dec_plot_res")
  frm_dec_graph <- rk.XML.frame(rk.XML.row(dec_plot_w, dec_plot_h, dec_plot_res), label = "HTML Graphics Size & Resolution")
  dec_plot_save <- rk.XML.saveobj("Save Plot (ggplot2) as", initial = "decomp_plot", chk = FALSE, id.name = "dec_plot_save")

  dec_preview <- rk.XML.preview(label = "Preview Decomposition Plot")

  # --- UI Logic ---
  cond_stl <- rk.XML.convert(sources = list(string = dec_method), mode = c(equals = "stl"), id.name = "cond_stl")

  logic_dec <- rk.XML.logic(
    cond_stl,
    rk.XML.connect(governor = cond_stl, client = frm_stl_opts, set = "enabled"),
    rk.XML.connect(governor = dec_stl_periodic, get = "state.not", client = dec_stl_swin, set = "enabled")
  )

  # --- Layout ---
  tab_dec <- rk.XML.tabbook(tabs = list(
    "Data & Method" = rk.XML.col(dec_ts, dec_method, frm_stl_opts, rk.XML.stretch()),
    "Plot Options" = rk.XML.col(frm_dec_plot, rk.XML.stretch()),
    "Output" = rk.XML.col(
      rk.XML.frame(dec_save, dec_save_adj, label = "Save Objects to Workspace"),
      frm_dec_graph,
      rk.XML.frame(dec_plot_save, label = "Save Plot Object"),
      rk.XML.stretch()
    )
  ))

  dialog_dec <- rk.XML.dialog(
    rk.XML.row(
      dec_vs,
      rk.XML.col(tab_dec, dec_preview)
    ),
    label = "2. Decomposition (Classical & STL)"
  )

  # --- JavaScript ---
  js_calc_dec <- "
    var ts_obj = getValue('dec_ts');
    var method = getValue('dec_method');
    var stl_per = getValue('dec_stl_periodic') === 'TRUE';
    var stl_win = getValue('dec_stl_swin');
    var stl_rob = getValue('dec_stl_robust') === 'TRUE';

    var theme = getValue('dec_theme');
    var main_tit = cleanStr(getValue('dec_plot_main'));
    var x_tit = cleanStr(getValue('dec_plot_xlab'));

    echo('x_ts <- ' + ts_obj + '\\n');
    echo('if (stats::frequency(x_ts) < 2) stop(\"Seasonal decomposition requires frequency >= 2 (e.g., Monthly or Quarterly).\")\\n');
    echo('if (anyNA(x_ts)) stop(\"Series contains NAs. Please impute missing values first using 1. Define Series & Impute Data.\")\\n\\n');

    if (method === 'stl') {
        var swin_arg = stl_per ? '\"periodic\"' : stl_win;
        var rob_arg = stl_rob ? 'TRUE' : 'FALSE';
        echo('ts_decomp <- stats::stl(x_ts, s.window = ' + swin_arg + ', robust = ' + rob_arg + ')\\n');
    } else {
        echo('ts_decomp <- stats::decompose(x_ts, type = \"' + method + '\")\\n');
    }

    // Regla de Oro #3: Hardcode para ts_seas_adj
    echo('ts_seas_adj <- forecast::seasadj(ts_decomp)\\n\\n');

    // Calcular métricas de Fuerza de Tendencia y Estacionalidad (Hyndman)
    echo('decomp_summary <- tryCatch({\\n');
    if (method === 'stl') {
        echo('  comp_mat <- ts_decomp$time.series\\n');
        echo('  trnd <- comp_mat[, \"trend\"]\\n');
        echo('  seas <- comp_mat[, \"seasonal\"]\\n');
        echo('  rem  <- comp_mat[, \"remainder\"]\\n');
        echo('  t_str <- round(max(0, 1 - stats::var(rem) / stats::var(trnd + rem)) * 100, 2)\\n');
        echo('  s_str <- round(max(0, 1 - stats::var(rem) / stats::var(seas + rem)) * 100, 2)\\n');
    } else {
        echo('  idx  <- !is.na(ts_decomp$random) & !is.na(ts_decomp$trend)\\n');
        echo('  trnd <- ts_decomp$trend[idx]\\n');
        echo('  seas <- ts_decomp$seasonal[idx]\\n');
        echo('  rem  <- ts_decomp$random[idx]\\n');
        if (method === 'multiplicative') {
            echo('  t_str <- round(max(0, 1 - stats::var(log(rem)) / stats::var(log(trnd * rem))) * 100, 2)\\n');
            echo('  s_str <- round(max(0, 1 - stats::var(log(rem)) / stats::var(log(seas * rem))) * 100, 2)\\n');
        } else {
            echo('  t_str <- round(max(0, 1 - stats::var(rem) / stats::var(trnd + rem)) * 100, 2)\\n');
            echo('  s_str <- round(max(0, 1 - stats::var(rem) / stats::var(seas + rem)) * 100, 2)\\n');
        }
    }
    echo('  data.frame(Metric = c(\"Trend Strength (%)\", \"Seasonal Strength (%)\"), Value = c(t_str, s_str))\\n');
    echo('}, error = function(e) data.frame(Note = \"Strength metrics unavailable for this series\"))\\n\\n');

    var default_tit = (method === 'stl') ? 'STL Decomposition: ' + ts_obj : 'Classical Decomposition (' + method + '): ' + ts_obj;
    var title_str = (main_tit !== '') ? main_tit : default_tit;

    echo('p <- ggplot2::autoplot(ts_decomp) + ggplot2::theme_' + theme + '() +\\n');
    echo('     ggplot2::labs(title = \"' + title_str + '\"');
    if (x_tit !== '') echo(', x = \"' + x_tit + '\"');
    echo(')\\n');
  "

  js_print_dec <- "
    var w = getValue('dec_plot_w');
    var h = getValue('dec_plot_h');
    var res = getValue('dec_plot_res');

    if (typeof is_preview !== 'undefined' && is_preview) {
        echo('print(p)\\n');
    }

    if (typeof is_preview === 'undefined' || !is_preview) {
        echo('rk.header(\"2. Time Series Decomposition\")\\n');

        echo('rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\\n');
        echo('print(p)\\n');
        echo('rk.graph.off()\\n\\n');

        echo('rk.header(\"Component Strength Metrics\", level = 3)\\n');
        echo('rk.print(decomp_summary)\\n');

        if (getValue('dec_save.active') || getValue('dec_save_adj.active') || getValue('dec_plot_save.active')) {
            echo('rk.print(\"<hr>\")\\n');
        }
        if (getValue('dec_save.active')) {
            echo('rk.print(paste0(\"<b>Decomposed object saved as: </b><code>\", \"' + getValue('dec_save') + '\", \"</code><br>\"))\\n');
        }
        if (getValue('dec_save_adj.active')) {
            echo('rk.print(paste0(\"<b>Seasonally adjusted series (ts) saved as: </b><code>\", \"' + getValue('dec_save_adj') + '\", \"</code><br>\"))\\n');
        }
        if (getValue('dec_plot_save.active')) {
            echo('p$plot_env <- emptyenv()\\n');
            echo('decomp_plot <- p\\n');
            echo('rk.print(paste0(\"<b>Plot object (ggplot2) saved as: </b><code>\", \"' + getValue('dec_plot_save') + '\", \"</code>\"))\\n');
        }
    }
  "

  comp_decomp <- rk.plugin.component(
    "2. Decomposition (Classical & STL)",
    xml = list(dialog = dialog_dec, logic = logic_dec),
    js = list(require = c("stats", "forecast", "ggplot2"), globals = js_helpers, calculate = js_calc_dec, printout = js_print_dec),
    hierarchy = h_ts
  )

  # =========================================================================================
  # 4. MODULE 3: 3. Diagnostics (FAC/FACP, Ljung-Box, ADF & KPSS)
  # =========================================================================================

  # --- UI Elements ---
  diag_vs <- rk.XML.varselector(id.name = "diag_vs")
  diag_ts <- rk.XML.varslot("Time Series Object (ts)", source = "diag_vs", classes = "ts", required = TRUE, id.name = "diag_ts")

  diag_log <- rk.XML.cbox("Apply Log Transformation (log) before differencing", value = "1", chk = FALSE, id.name = "diag_log")
  diag_diff <- rk.XML.spinbox("Regular Differencing Order (d)", min = 0, max = 3, initial = 0, real = FALSE, id.name = "diag_diff")
  diag_sdiff <- rk.XML.spinbox("Seasonal Differencing Order (D)", min = 0, max = 2, initial = 0, real = FALSE, id.name = "diag_sdiff")
  frm_diag_trans <- rk.XML.frame(diag_log, diag_diff, diag_sdiff, label = "Stationarity Transformations (Optional)")

  diag_plot_type <- rk.XML.radio("Diagnostic Plot Type", options = list(
    "Full Display (Series + ACF + PACF)" = list(val = "display", chk = TRUE),
    "ACF Plot Only (Autocorrelation)" = list(val = "acf"),
    "PACF Plot Only (Partial Autocorrelation)" = list(val = "pacf")
  ), id.name = "diag_plot_type")

  diag_lags <- rk.XML.spinbox("Max Lags for Plots & Ljung-Box (0 = Auto)", min = 0, max = 120, initial = 0, real = FALSE, id.name = "diag_lags")

  diag_chk_lb <- rk.XML.cbox("Ljung-Box Test (Autocorrelation / White Noise)", value = "1", chk = TRUE, id.name = "diag_chk_lb")
  diag_chk_adf <- rk.XML.cbox("Augmented Dickey-Fuller Test (ADF - Stationarity)", value = "1", chk = TRUE, id.name = "diag_chk_adf")
  diag_chk_kpss <- rk.XML.cbox("KPSS Test (Level/Trend Stationarity)", value = "1", chk = TRUE, id.name = "diag_chk_kpss")
  frm_diag_tests <- rk.XML.frame(diag_chk_lb, diag_chk_adf, diag_chk_kpss, label = "Statistical Hypothesis Tests")

  diag_theme <- rk.XML.dropdown("Plot Theme (ggplot2)", options = list(
    "Minimal (Clean business look)" = list(val = "minimal", chk = TRUE),
    "Classic (Scientific)" = list(val = "classic"),
    "Black & White (Grid)" = list(val = "bw")
  ), id.name = "diag_theme")
  diag_plot_main <- rk.XML.input("Main Title (For ACF/PACF Only - Leave empty for default)", id.name = "diag_plot_main")

  # Output Options
  diag_save_ts <- rk.XML.saveobj("Save transformed/differenced series (ts) as", initial = "ts_diag", chk = FALSE, id.name = "diag_save_ts")
  diag_plot_w <- rk.XML.spinbox("HTML Plot Width (pixels)", min = 100, max = 5000, initial = 900, real = FALSE, id.name = "diag_plot_w")
  diag_plot_h <- rk.XML.spinbox("HTML Plot Height (pixels)", min = 100, max = 5000, initial = 650, real = FALSE, id.name = "diag_plot_h")
  diag_plot_res <- rk.XML.spinbox("Resolution (DPI)", min = 72, max = 600, initial = 120, real = FALSE, id.name = "diag_plot_res")
  frm_diag_graph <- rk.XML.frame(rk.XML.row(diag_plot_w, diag_plot_h, diag_plot_res), label = "HTML Graphics Size & Resolution")
  diag_plot_save <- rk.XML.saveobj("Save Plot Object as", initial = "diag_plot", chk = FALSE, id.name = "diag_plot_save")

  diag_preview <- rk.XML.preview(label = "Preview Diagnostic Plot")

  # --- UI Logic ---
  logic_diag <- rk.XML.logic()

  # --- Layout ---
  tab_diag <- rk.XML.tabbook(tabs = list(
    "Data & Differencing" = rk.XML.col(diag_ts, frm_diag_trans, rk.XML.stretch()),
    "Tests & Plots" = rk.XML.col(diag_plot_type, diag_lags, frm_diag_tests, diag_theme, diag_plot_main, rk.XML.stretch()),
    "Output" = rk.XML.col(
      rk.XML.frame(diag_save_ts, label = "Save Transformed Series"),
      frm_diag_graph,
      rk.XML.frame(diag_plot_save, label = "Save Plot Object"),
      rk.XML.stretch()
    )
  ))

  dialog_diag <- rk.XML.dialog(
    rk.XML.row(
      diag_vs,
      rk.XML.col(tab_diag, diag_preview)
    ),
    label = "3. Diagnostics (ACF/PACF, Ljung-Box, ADF)"
  )

  # --- JavaScript ---
  js_calc_diag <- "
    var ts_obj = getValue('diag_ts');
    var do_log = getValue('diag_log') === '1';
    var d_ord = getValue('diag_diff');
    var D_ord = getValue('diag_sdiff');

    var plot_type = getValue('diag_plot_type');
    var lags = getValue('diag_lags');
    var theme = getValue('diag_theme');
    var main_tit = cleanStr(getValue('diag_plot_main'));

    var chk_lb = getValue('diag_chk_lb') === '1';
    var chk_adf = getValue('diag_chk_adf') === '1';
    var chk_kpss = getValue('diag_chk_kpss') === '1';

    echo('ts_diag <- ' + ts_obj + '\\n');
    if (do_log) {
        echo('if (any(ts_diag <= 0, na.rm = TRUE)) stop(\"Log transformation requires strictly positive values.\")\\n');
        echo('ts_diag <- log(ts_diag)\\n');
    }
    if (D_ord > 0) {
        echo('if (stats::frequency(ts_diag) > 1) {\\n');
        echo('  ts_diag <- diff(ts_diag, lag = stats::frequency(ts_diag), differences = ' + D_ord + ')\\n');
        echo('}\\n');
    }
    if (d_ord > 0) {
        echo('ts_diag <- diff(ts_diag, differences = ' + d_ord + ')\\n');
    }
    echo('ts_diag_clean <- stats::na.omit(ts_diag)\\n\\n');

    // Construir tabla de pruebas estadísticas
    echo('diag_tests <- data.frame(Test = character(), Statistic = numeric(), Parameter = character(), P_Value = numeric(), Interpretation = character(), stringsAsFactors = FALSE)\\n');

    if (chk_lb) {
        echo('n_obs <- length(ts_diag_clean)\\n');
        echo('m_freq <- stats::frequency(ts_diag_clean)\\n');
        if (lags > 0) {
            echo('lb_lag <- max(1, min(' + lags + ', n_obs - 1))\\n');
        } else {
            echo('lb_lag <- if (m_freq > 1) min(2 * m_freq, floor(n_obs / 5)) else min(10, floor(n_obs / 5))\\n');
            echo('lb_lag <- max(1, lb_lag)\\n');
        }
        echo('tryCatch({\\n');
        echo('  lb_res <- stats::Box.test(ts_diag_clean, lag = lb_lag, type = \"Ljung-Box\")\\n');
        echo('  lb_int <- ifelse(lb_res$p.value < 0.05, \"Autocorrelation detected (Not White Noise)\", \"No significant autocorrelation (White Noise)\")\\n');
        echo('  diag_tests <- rbind(diag_tests, data.frame(Test = \"Ljung-Box (Q*)\", Statistic = round(as.numeric(lb_res$statistic), 4), Parameter = paste(\"lag =\", lb_lag), P_Value = round(lb_res$p.value, 4), Interpretation = lb_int))\\n');
        echo('}, error = function(e) {})\\n');
    }

    if (chk_adf) {
        echo('tryCatch({\\n');
        echo('  adf_res <- suppressWarnings(tseries::adf.test(ts_diag_clean))\\n');
        echo('  adf_int <- ifelse(adf_res$p.value < 0.05, \"Stationary (Reject unit root)\", \"Non-Stationary (Needs differencing)\")\\n');
        echo('  diag_tests <- rbind(diag_tests, data.frame(Test = \"Augmented Dickey-Fuller (ADF)\", Statistic = round(as.numeric(adf_res$statistic), 4), Parameter = paste(\"lag =\", adf_res$parameter), P_Value = round(adf_res$p.value, 4), Interpretation = adf_int))\\n');
        echo('}, error = function(e) {})\\n');
    }

    if (chk_kpss) {
        echo('tryCatch({\\n');
        echo('  kpss_res <- suppressWarnings(tseries::kpss.test(ts_diag_clean))\\n');
        echo('  kpss_int <- ifelse(kpss_res$p.value < 0.05, \"Non-Stationary (Reject stationarity)\", \"Stationary (Cannot reject stationarity)\")\\n');
        echo('  diag_tests <- rbind(diag_tests, data.frame(Test = \"KPSS (Level)\", Statistic = round(as.numeric(kpss_res$statistic), 4), Parameter = paste(\"trunc =\", kpss_res$parameter), P_Value = round(kpss_res$p.value, 4), Interpretation = kpss_int))\\n');
        echo('}, error = function(e) {})\\n');
    }
    echo('\\n');

    // Si es ACF o PACF individual, preparamos el objeto ggplot 'p' aquí
    if (plot_type !== 'display') {
        var fn = (plot_type === 'acf') ? 'ggAcf' : 'ggPacf';
        var lag_arg = (lags > 0) ? ', lag.max = ' + lags : '';
        var def_tit = (plot_type === 'acf') ? 'ACF (Autocorrelation): ' + ts_obj : 'PACF (Partial Autocorrelation): ' + ts_obj;
        var title_str = (main_tit !== '') ? main_tit : def_tit;

        echo('p <- forecast::' + fn + '(ts_diag_clean' + lag_arg + ') + ggplot2::theme_' + theme + '() +\\n');
        echo('     ggplot2::labs(title = \"' + title_str + '\")\\n');
    }
  "

  js_print_diag <- "
    var plot_type = getValue('diag_plot_type');
    var lags = getValue('diag_lags');
    var theme = getValue('diag_theme');
    var w = getValue('diag_plot_w');
    var h = getValue('diag_plot_h');
    var res = getValue('diag_plot_res');

    var lag_arg = (lags > 0) ? ', lag.max = ' + lags : '';
    var display_cmd = 'forecast::ggtsdisplay(ts_diag_clean, plot.type = \"partial\"' + lag_arg + ', theme = ggplot2::theme_' + theme + '())';

    if (typeof is_preview !== 'undefined' && is_preview) {
        if (plot_type === 'display') {
            echo(display_cmd + '\\n');
        } else {
            echo('print(p)\\n');
        }
    }

    if (typeof is_preview === 'undefined' || !is_preview) {
        echo('rk.header(\"3. Time Series Diagnostics\")\\n');

        echo('rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\\n');
        if (plot_type === 'display') {
            echo(display_cmd + '\\n');
            if (getValue('diag_plot_save.active')) {
                echo('diag_plot <- recordPlot()\\n');
            }
        } else {
            echo('print(p)\\n');
        }
        echo('rk.graph.off()\\n\\n');

        if (plot_type !== 'display' && getValue('diag_plot_save.active')) {
            echo('p$plot_env <- emptyenv()\\n');
            echo('diag_plot <- p\\n');
        }

        echo('if (nrow(diag_tests) > 0) {\\n');
        echo('  rk.header(\"Hypothesis Tests (Stationarity & White Noise)\", level = 3)\\n');
        echo('  rk.print(diag_tests)\\n');
        echo('}\\n');

        if (getValue('diag_save_ts.active') || getValue('diag_plot_save.active')) {
            echo('rk.print(\"<hr>\")\\n');
        }
        if (getValue('diag_save_ts.active')) {
            echo('rk.print(paste0(\"<b>Transformed series (ts) saved as: </b><code>\", \"' + getValue('diag_save_ts') + '\", \"</code><br>\"))\\n');
        }
        if (getValue('diag_plot_save.active')) {
            echo('rk.print(paste0(\"<b>Plot object saved as: </b><code>\", \"' + getValue('diag_plot_save') + '\", \"</code>\"))\\n');
        }
    }
  "

  comp_diag <- rk.plugin.component(
    "3. Diagnostics (ACF/PACF, Ljung-Box, ADF)",
    xml = list(dialog = dialog_diag, logic = logic_diag),
    js = list(require = c("stats", "forecast", "tseries", "ggplot2"), globals = js_helpers, calculate = js_calc_diag, printout = js_print_diag),
    hierarchy = h_ts
  )

  # =========================================================================================
  # 5. BUILD SKELETON
  # =========================================================================================

  unlink("rk.ts.prep", recursive = TRUE)

  rk.plugin.skeleton(
    about = package_about,
    path = ".",
    xml = list(dialog = dialog_prep, logic = logic_prep),
    js = list(
      require = c("imputeTS", "forecast", "ggplot2"),
      globals = js_helpers,
      calculate = js_calc_prep,
      printout = js_print_prep
    ),
    components = list(comp_decomp, comp_diag),
    pluginmap = list(
      name = "1. Define Series & Impute Data",
      hierarchy = h_ts
    ),
    dependencies = dependencies_node,
    create = c("pmap", "xml", "js", "desc", "rkh"),
    overwrite = TRUE,
    load = TRUE,
    show = FALSE
  )

  cat("\nPackage 'rk.ts.prep' generated successfully.\n")
})
