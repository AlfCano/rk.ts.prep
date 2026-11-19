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
		echo("if(!base::require(imputeTS)){stop(" + i18n("Preview not available, because package imputeTS is not installed or cannot be loaded.") + ")}\n");
	} else {
		echo("require(imputeTS)\n");
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

    echo('raw_vector <- ' + data + '[["' + target + '"]]\n');
    if (trim_na) {
        echo('non_na_idx <- which(!is.na(raw_vector))\n');
        echo('if (length(non_na_idx) > 0) raw_vector <- raw_vector[min(non_na_idx):max(non_na_idx)]\n');
    }
    echo('ts_raw <- stats::ts(raw_vector, frequency = ' + freq_val + ', start = c(' + yr + ', ' + pd + '))\n\n');

    // Regla de Oro #3: Hardcode exacto al 'initial' de prep_save ('ts_clean')
    if (method === 'none') {
        echo('ts_clean <- ts_raw\n');
    } else {
        echo('if (anyNA(ts_raw)) {\n');
        if (method === 'linear') {
            echo('  ts_clean <- imputeTS::na_interpolation(ts_raw, option = "linear")\n');
        } else if (method === 'spline') {
            echo('  ts_clean <- imputeTS::na_interpolation(ts_raw, option = "spline")\n');
        } else if (method === 'kalman') {
            echo('  ts_clean <- imputeTS::na_kalman(ts_raw, model = "StructTS")\n');
        } else if (method === 'seadec') {
            echo('  if (frequency(ts_raw) < 2) {\n');
            echo('    ts_clean <- imputeTS::na_interpolation(ts_raw, option = "linear")\n');
            echo('  } else {\n');
            echo('    ts_clean <- imputeTS::na_seadec(ts_raw, algorithm = "interpolation")\n');
            echo('  }\n');
        } else if (method === 'locf') {
            echo('  ts_clean <- imputeTS::na_locf(ts_raw)\n');
        }
        echo('} else {\n');
        echo('  ts_clean <- ts_raw\n');
        echo('}\n');
    }
    echo('\n');

    // Plot inteligente dependiendo de si hubo NAs e imputación
    var title_str = (main_tit !== '') ? main_tit : 'Time Series: ' + target;
    echo('if (anyNA(ts_raw) && !anyNA(ts_clean)) {\n');
    echo('  p <- imputeTS::ggplot_na_imputations(x_with_na = ts_raw, x_with_imputations = ts_clean) +\n');
    echo('       ggplot2::theme_' + theme + '()\n');
    echo('} else if (anyNA(ts_raw)) {\n');
    echo('  p <- imputeTS::ggplot_na_distribution(ts_raw) +\n');
    echo('       ggplot2::theme_' + theme + '()\n');
    echo('} else {\n');
    echo('  p <- ggplot2::autoplot(ts_clean) +\n');
    echo('       ggplot2::theme_' + theme + '()\n');
    echo('}\n');

    echo('p <- p + ggplot2::labs(title = "' + title_str + '"');
    if (x_tit !== '') echo(', x = "' + x_tit + '"');
    if (y_tit !== '') echo(', y = "' + y_tit + '"');
    echo(')\n\n');

    echo('prep_summary <- data.frame(\n');
    echo('  Start = paste(stats::start(ts_clean), collapse = "-"),\n');
    echo('  End = paste(stats::end(ts_clean), collapse = "-"),\n');
    echo('  Frequency = stats::frequency(ts_clean),\n');
    echo('  Observations = length(ts_clean),\n');
    echo('  NAs_Before = sum(is.na(ts_raw)),\n');
    echo('  NAs_After = sum(is.na(ts_clean))\n');
    echo(')\n');
  
}

function printout(is_preview){
	// read in variables from dialog


	// printout the results
	if(!is_preview) {
		new Header(i18n("1. Define Series & Impute Data results")).print();	
	}
    var w = getValue('prep_plot_w');
    var h = getValue('prep_plot_h');
    var res = getValue('prep_plot_res');

    if (typeof is_preview !== 'undefined' && is_preview) {
        echo('print(p)\n');
    }

    if (typeof is_preview === 'undefined' || !is_preview) {
        echo('rk.header("1. Time Series Preparation & Imputation")\n');

        echo('rk.graph.on(width = ' + w + ', height = ' + h + ', res = ' + res + ')\n');
        echo('print(p)\n');
        echo('rk.graph.off()\n\n');

        echo('rk.header("Series Summary", level = 3)\n');
        echo('rk.print(prep_summary)\n');

        if (getValue('prep_save.active') || getValue('prep_plot_save.active')) { echo('rk.print("<hr>")\n'); }
        if (getValue('prep_save.active')) {
            echo('rk.print(paste0("<b>Time Series (ts) saved as: </b><code>", "' + getValue('prep_save') + '", "</code><br>"))\n');
        }
        if (getValue('prep_plot_save.active')) {
            // Regla de Oro #12: Vaciar entorno de ggplot antes de guardar
            echo('p$plot_env <- emptyenv()\n');
            echo('prep_plot <- p\n');
            echo('rk.print(paste0("<b>Plot object (ggplot2) saved as: </b><code>", "' + getValue('prep_plot_save') + '", "</code>"))\n');
        }
    }
  
	if(!is_preview) {
		//// save result object
		// read in saveobject variables
		var prepSave = getValue("prep_save");
		var prepSaveActive = getValue("prep_save.active");
		var prepSaveParent = getValue("prep_save.parent");		var prepPlotSave = getValue("prep_plot_save");
		var prepPlotSaveActive = getValue("prep_plot_save.active");
		var prepPlotSaveParent = getValue("prep_plot_save.parent");
		// assign object to chosen environment
		if(prepSaveActive) {
			echo(".GlobalEnv$" + prepSave + " <- ts_clean\n");
		}
		if(prepPlotSaveActive) {
			echo(".GlobalEnv$" + prepPlotSave + " <- prep_plot\n");
		}	
	}

}

