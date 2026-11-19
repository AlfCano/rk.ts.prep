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
		echo("if(!base::require(ggplot2)){stop(" + i18n("Preview not available, because package ggplot2 is not installed or cannot be loaded.") + ")}\n");
	} else {
		echo("require(ggplot2)\n");
	}
}

function calculate(is_preview){
	// read in variables from dialog


	// the R code to be evaluated

    var ts_obj = getValue('dec_ts');
    var method = getValue('dec_method');
    var stl_per = getValue('dec_stl_periodic') === 'TRUE';
    var stl_win = getValue('dec_stl_swin');
    var stl_rob = getValue('dec_stl_robust') === 'TRUE';

    var theme = getValue('dec_theme');
    var main_tit = cleanStr(getValue('dec_plot_main'));
    var x_tit = cleanStr(getValue('dec_plot_xlab'));

    echo('x_ts <- ' + ts_obj + '\n');
    echo('if (stats::frequency(x_ts) < 2) stop("Seasonal decomposition requires frequency >= 2 (e.g., Monthly or Quarterly).")\n');
    echo('if (anyNA(x_ts)) stop("Series contains NAs. Please impute missing values first using 1. Define Series & Impute Data.")\n\n');

    if (method === 'stl') {
        var swin_arg = stl_per ? '"periodic"' : stl_win;
        var rob_arg = stl_rob ? 'TRUE' : 'FALSE';
        echo('ts_decomp <- stats::stl(x_ts, s.window = ' + swin_arg + ', robust = ' + rob_arg + ')\n');
    } else {
        echo('ts_decomp <- stats::decompose(x_ts, type = "' + method + '")\n');
    }

    // Regla de Oro #3: Hardcode para ts_seas_adj
    echo('ts_seas_adj <- forecast::seasadj(ts_decomp)\n\n');

    // Calcular métricas de Fuerza de Tendencia y Estacionalidad (Hyndman)
    echo('decomp_summary <- tryCatch({\n');
    if (method === 'stl') {
        echo('  comp_mat <- ts_decomp$time.series\n');
        echo('  trnd <- comp_mat[, "trend"]\n');
        echo('  seas <- comp_mat[, "seasonal"]\n');
        echo('  rem  <- comp_mat[, "remainder"]\n');
        echo('  t_str <- round(max(0, 1 - stats::var(rem) / stats::var(trnd + rem)) * 100, 2)\n');
        echo('  s_str <- round(max(0, 1 - stats::var(rem) / stats::var(seas + rem)) * 100, 2)\n');
    } else {
        echo('  idx  <- !is.na(ts_decomp$random) & !is.na(ts_decomp$trend)\n');
        echo('  trnd <- ts_decomp$trend[idx]\n');
        echo('  seas <- ts_decomp$seasonal[idx]\n');
        echo('  rem  <- ts_decomp$random[idx]\n');
        if (method === 'multiplicative') {
            echo('  t_str <- round(max(0, 1 - stats::var(log(rem)) / stats::var(log(trnd * rem))) * 100, 2)\n');
            echo('  s_str <- round(max(0, 1 - stats::var(log(rem)) / stats::var(log(seas * rem))) * 100, 2)\n');
        } else {
            echo('  t_str <- round(max(0, 1 - stats::var(rem) / stats::var(trnd + rem)) * 100, 2)\n');
            echo('  s_str <- round(max(0, 1 - stats::var(rem) / stats::var(seas + rem)) * 100, 2)\n');
        }
    }
    echo('  data.frame(Metric = c("Trend Strength (%)", "Seasonal Strength (%)"), Value = c(t_str, s_str))\n');
    echo('}, error = function(e) data.frame(Note = "Strength metrics unavailable for this series"))\n\n');

    var default_tit = (method === 'stl') ? 'STL Decomposition: ' + ts_obj : 'Classical Decomposition (' + method + '): ' + ts_obj;
    var title_str = (main_tit !== '') ? main_tit : default_tit;

    echo('p <- ggplot2::autoplot(ts_decomp) + ggplot2::theme_' + theme + '() +\n');
    echo('     ggplot2::labs(title = "' + title_str + '"');
    if (x_tit !== '') echo(', x = "' + x_tit + '"');
    echo(')\n');
  
}

function printout(is_preview){
	// read in variables from dialog


	// printout the results
	if(!is_preview) {
		new Header(i18n("2. Decomposition (Classical & STL) results")).print();	
	}
    var w = getValue('dec_plot_w');
    var h = getValue('dec_plot_h');
    var res = getValue('dec_plot_res');

    if (typeof is_preview !== 'undefined' && is_preview) {
        echo('print(p)\n');
    }

    if (typeof is_preview === 'undefined' || !is_preview) {
        echo('rk.header("2. Time Series Decomposition")\n');

        echo('rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\n');
        echo('print(p)\n');
        echo('rk.graph.off()\n\n');

        echo('rk.header("Component Strength Metrics", level = 3)\n');
        echo('rk.print(decomp_summary)\n');

        if (getValue('dec_save.active') || getValue('dec_save_adj.active') || getValue('dec_plot_save.active')) {
            echo('rk.print("<hr>")\n');
        }
        if (getValue('dec_save.active')) {
            echo('rk.print(paste0("<b>Decomposed object saved as: </b><code>", "' + getValue('dec_save') + '", "</code><br>"))\n');
        }
        if (getValue('dec_save_adj.active')) {
            echo('rk.print(paste0("<b>Seasonally adjusted series (ts) saved as: </b><code>", "' + getValue('dec_save_adj') + '", "</code><br>"))\n');
        }
        if (getValue('dec_plot_save.active')) {
            echo('p$plot_env <- emptyenv()\n');
            echo('decomp_plot <- p\n');
            echo('rk.print(paste0("<b>Plot object (ggplot2) saved as: </b><code>", "' + getValue('dec_plot_save') + '", "</code>"))\n');
        }
    }
  
	if(!is_preview) {
		//// save result object
		// read in saveobject variables
		var decSave = getValue("dec_save");
		var decSaveActive = getValue("dec_save.active");
		var decSaveParent = getValue("dec_save.parent");		var decSaveAdj = getValue("dec_save_adj");
		var decSaveAdjActive = getValue("dec_save_adj.active");
		var decSaveAdjParent = getValue("dec_save_adj.parent");		var decPlotSave = getValue("dec_plot_save");
		var decPlotSaveActive = getValue("dec_plot_save.active");
		var decPlotSaveParent = getValue("dec_plot_save.parent");
		// assign object to chosen environment
		if(decSaveActive) {
			echo(".GlobalEnv$" + decSave + " <- ts_decomp\n");
		}
		if(decSaveAdjActive) {
			echo(".GlobalEnv$" + decSaveAdj + " <- ts_seas_adj\n");
		}
		if(decPlotSaveActive) {
			echo(".GlobalEnv$" + decPlotSave + " <- decomp_plot\n");
		}	
	}

}

