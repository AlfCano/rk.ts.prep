// this code was generated using the rkwarddev package.
// perhaps don't make changes here, but in the rkwarddev script instead!

// define variables globally
    function cleanStr(val) {
        if(!val) return '';
        return val.replace(/'/g, "\\'").replace(/"/g, '\\"');
    }

    function parseVar(fullPath) {
        if (!fullPath) return '';
        var raw_col = '';
        if (fullPath.indexOf('[[') > -1) {
            var parts = fullPath.split('[[');
            var inner = parts[1].replace(']]', '');
            raw_col = inner.replace(/["']/g, '');
        } else if (fullPath.indexOf('$') > -1) {
            raw_col = fullPath.split('$')[1];
        } else {
            raw_col = fullPath;
        }
        return raw_col;
    }
  

function preview(){
	preprocess(true);
	calculate(true);
	printout(true);
}

function preprocess(is_preview){
	// add requirements etc. here
	if(is_preview) {
		echo("if(!base::require(stats)){stop(" + i18n("Preview not available, because package stats is not installed or cannot be loaded.") + ")}\n");
	} else {
		echo("require(stats)\n");
	}	if(is_preview) {
		echo("if(!base::require(forecast)){stop(" + i18n("Preview not available, because package forecast is not installed or cannot be loaded.") + ")}\n");
	} else {
		echo("require(forecast)\n");
	}	if(is_preview) {
		echo("if(!base::require(tseries)){stop(" + i18n("Preview not available, because package tseries is not installed or cannot be loaded.") + ")}\n");
	} else {
		echo("require(tseries)\n");
	}	if(is_preview) {
		echo("if(!base::require(ggplot2)){stop(" + i18n("Preview not available, because package ggplot2 is not installed or cannot be loaded.") + ")}\n");
	} else {
		echo("require(ggplot2)\n");
	}
}

function calculate(is_preview){
	// read in variables from dialog


	// the R code to be evaluated

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

    echo('ts_diag <- ' + ts_obj + '\n');
    if (do_log) {
        echo('if (any(ts_diag <= 0, na.rm = TRUE)) stop("Log transformation requires strictly positive values.")\n');
        echo('ts_diag <- log(ts_diag)\n');
    }
    if (D_ord > 0) {
        echo('if (stats::frequency(ts_diag) > 1) {\n');
        echo('  ts_diag <- diff(ts_diag, lag = stats::frequency(ts_diag), differences = ' + D_ord + ')\n');
        echo('}\n');
    }
    if (d_ord > 0) {
        echo('ts_diag <- diff(ts_diag, differences = ' + d_ord + ')\n');
    }
    echo('ts_diag_clean <- stats::na.omit(ts_diag)\n\n');

    // Construir tabla de pruebas estadísticas
    echo('diag_tests <- data.frame(Test = character(), Statistic = numeric(), Parameter = character(), P_Value = numeric(), Interpretation = character(), stringsAsFactors = FALSE)\n');

    if (chk_lb) {
        echo('n_obs <- length(ts_diag_clean)\n');
        echo('m_freq <- stats::frequency(ts_diag_clean)\n');
        if (lags > 0) {
            echo('lb_lag <- max(1, min(' + lags + ', n_obs - 1))\n');
        } else {
            echo('lb_lag <- if (m_freq > 1) min(2 * m_freq, floor(n_obs / 5)) else min(10, floor(n_obs / 5))\n');
            echo('lb_lag <- max(1, lb_lag)\n');
        }
        echo('tryCatch({\n');
        echo('  lb_res <- stats::Box.test(ts_diag_clean, lag = lb_lag, type = "Ljung-Box")\n');
        echo('  lb_int <- ifelse(lb_res$p.value < 0.05, "Autocorrelation detected (Not White Noise)", "No significant autocorrelation (White Noise)")\n');
        echo('  diag_tests <- rbind(diag_tests, data.frame(Test = "Ljung-Box (Q*)", Statistic = round(as.numeric(lb_res$statistic), 4), Parameter = paste("lag =", lb_lag), P_Value = round(lb_res$p.value, 4), Interpretation = lb_int))\n');
        echo('}, error = function(e) {})\n');
    }

    if (chk_adf) {
        echo('tryCatch({\n');
        echo('  adf_res <- suppressWarnings(tseries::adf.test(ts_diag_clean))\n');
        echo('  adf_int <- ifelse(adf_res$p.value < 0.05, "Stationary (Reject unit root)", "Non-Stationary (Needs differencing)")\n');
        echo('  diag_tests <- rbind(diag_tests, data.frame(Test = "Augmented Dickey-Fuller (ADF)", Statistic = round(as.numeric(adf_res$statistic), 4), Parameter = paste("lag =", adf_res$parameter), P_Value = round(adf_res$p.value, 4), Interpretation = adf_int))\n');
        echo('}, error = function(e) {})\n');
    }

    if (chk_kpss) {
        echo('tryCatch({\n');
        echo('  kpss_res <- suppressWarnings(tseries::kpss.test(ts_diag_clean))\n');
        echo('  kpss_int <- ifelse(kpss_res$p.value < 0.05, "Non-Stationary (Reject stationarity)", "Stationary (Cannot reject stationarity)")\n');
        echo('  diag_tests <- rbind(diag_tests, data.frame(Test = "KPSS (Level)", Statistic = round(as.numeric(kpss_res$statistic), 4), Parameter = paste("trunc =", kpss_res$parameter), P_Value = round(kpss_res$p.value, 4), Interpretation = kpss_int))\n');
        echo('}, error = function(e) {})\n');
    }
    echo('\n');

    // Si es ACF o PACF individual, preparamos el objeto ggplot 'p' aquí
    if (plot_type !== 'display') {
        var fn = (plot_type === 'acf') ? 'ggAcf' : 'ggPacf';
        var lag_arg = (lags > 0) ? ', lag.max = ' + lags : '';
        var def_tit = (plot_type === 'acf') ? 'ACF (Autocorrelation): ' + ts_obj : 'PACF (Partial Autocorrelation): ' + ts_obj;
        var title_str = (main_tit !== '') ? main_tit : def_tit;

        echo('p <- forecast::' + fn + '(ts_diag_clean' + lag_arg + ') + ggplot2::theme_' + theme + '() +\n');
        echo('     ggplot2::labs(title = "' + title_str + '")\n');
    }
  
}

function printout(is_preview){
	// read in variables from dialog


	// printout the results
	if(!is_preview) {
		new Header(i18n("3. Diagnostics (ACF/PACF, Ljung-Box, ADF) results")).print();	
	}
    var plot_type = getValue('diag_plot_type');
    var lags = getValue('diag_lags');
    var theme = getValue('diag_theme');
    var w = getValue('diag_plot_w');
    var h = getValue('diag_plot_h');
    var res = getValue('diag_plot_res');

    var lag_arg = (lags > 0) ? ', lag.max = ' + lags : '';
    var display_cmd = 'forecast::ggtsdisplay(ts_diag_clean, plot.type = "partial"' + lag_arg + ', theme = ggplot2::theme_' + theme + '())';

    if (typeof is_preview !== 'undefined' && is_preview) {
        if (plot_type === 'display') {
            echo(display_cmd + '\n');
        } else {
            echo('print(p)\n');
        }
    }

    if (typeof is_preview === 'undefined' || !is_preview) {
        echo('rk.header("3. Time Series Diagnostics")\n');

        echo('rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\n');
        if (plot_type === 'display') {
            echo(display_cmd + '\n');
            if (getValue('diag_plot_save.active')) {
                echo('diag_plot <- recordPlot()\n');
            }
        } else {
            echo('print(p)\n');
        }
        echo('rk.graph.off()\n\n');

        if (plot_type !== 'display' && getValue('diag_plot_save.active')) {
            echo('p$plot_env <- emptyenv()\n');
            echo('diag_plot <- p\n');
        }

        echo('if (nrow(diag_tests) > 0) {\n');
        echo('  rk.header("Hypothesis Tests (Stationarity & White Noise)", level = 3)\n');
        echo('  rk.print(diag_tests)\n');
        echo('}\n');

        if (getValue('diag_save_ts.active') || getValue('diag_plot_save.active')) {
            echo('rk.print("<hr>")\n');
        }
        if (getValue('diag_save_ts.active')) {
            echo('rk.print(paste0("<b>Transformed series (ts) saved as: </b><code>", "' + getValue('diag_save_ts') + '", "</code><br>"))\n');
        }
        if (getValue('diag_plot_save.active')) {
            echo('rk.print(paste0("<b>Plot object saved as: </b><code>", "' + getValue('diag_plot_save') + '", "</code>"))\n');
        }
    }
  
	if(!is_preview) {
		//// save result object
		// read in saveobject variables
		var diagSaveTs = getValue("diag_save_ts");
		var diagSaveTsActive = getValue("diag_save_ts.active");
		var diagSaveTsParent = getValue("diag_save_ts.parent");		var diagPlotSave = getValue("diag_plot_save");
		var diagPlotSaveActive = getValue("diag_plot_save.active");
		var diagPlotSaveParent = getValue("diag_plot_save.parent");
		// assign object to chosen environment
		if(diagSaveTsActive) {
			echo(".GlobalEnv$" + diagSaveTs + " <- ts_diag\n");
		}
		if(diagPlotSaveActive) {
			echo(".GlobalEnv$" + diagPlotSave + " <- diag_plot\n");
		}	
	}

}

