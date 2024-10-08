
#### Define visual encoding classes for 'vizi' ####
## ------------------------------------------------

vizi <- function(data, ..., encoding = NULL, mark = NULL, params = NULL)
{
	if ( missing(data) )
		data <- NULL
	encoding <- merge_encoding(encoding, as_encoding(...))
	props <- compute_properties(encoding, data=data)
	encoding <- props$encoding
	channels <- props$channels
	coord <- list(xlim=NULL, ylim=NULL, log="", asp=NA, grid=TRUE)
	plot <- structure(list(encoding=encoding, channels=channels,
		marks=list(), coord=coord, params=params), class="vizi_plot")
	if ( !is.null(mark) ) {
		for ( mk in mark )
			plot <- add_mark(plot, mk)
	}
	plot
}

add_mark <- function(plot, mark, ..., encoding = NULL,
	data = NULL, trans = NULL, params = NULL)
{
	if ( !inherits(plot, c("vizi_plot", "vizi_facets")) )
		matter_error("'plot' must inherit from 'vizi_plot' or 'vizi_facets")
	cls <- paste0("vizi_", mark)
	if ( !existsMethod("plot", cls) )
		matter_error("no known plot() method for class: ", sQuote(cls))
	# encode new variables
	if ( ...length() > 0L || !is.null(encoding) ) {
		encoding <- merge_encoding(encoding, as_encoding(...))
		props <- compute_properties(encoding, data=data)
		plot$channels <- merge_channels(props$channels, plot$channels)
		encoding <- props$encoding
	}
	# create mark
	params <- normalize_encoding(params)
	mk <- structure(list(encoding=encoding,
		params=params, trans=trans), class=cls)
	if ( is(plot, "vizi_facets") ) {
		# subset and assign mark to facets
		mks <- rep.int(list(mk), length(plot$plots))
		for ( i in seq_along(mks) ) {
			v <- plot$subscripts[[i]]
			if ( !is.null(encoding) && !is.null(v) ) {
				e <- lapply(encoding, function(x) x[v])
				mks[[i]]$encoding <- e
			}
			pmks <- plot$plots[[i]]$marks
			mk <- set_names(list(mks[[i]]), mark)
			plot$plots[[i]]$marks <- c(pmks, mk)
		}
	} else {
		# assign mark
		mk <- set_names(list(mk), mark)
		plot$marks <- c(plot$marks, mk)
	}
	plot
}

add_facets <- function(plot, by = NULL, data = NULL,
	nrow = NA, ncol = NA, labels = NULL, drop = TRUE, free = "")
{
	if ( !inherits(plot, c("vizi_plot", "vizi_facets")) )
		matter_error("'plot' must inherit from 'vizi_plot' or 'vizi_facets")
	# encode faceting variable
	if ( is(by, "formula") ) {
		by <- parse_formula(by, data)
		by <- c(by$lhs, by$rhs)
	} else {
		by <- list(by)
		by <- compute_variables(by, data)
	}
	if ( any(!is.na(c(nrow, ncol))) ) {
		nshingles <- max(c(nrow, ncol), na.rm=TRUE)
	} else {
		nshingles <- 6L
	}
	# calculate the facets
	facets <- compute_facets(plot, by, nshingles)
	if ( !is.null(labels) )
		facets$labels <- labels
	if ( is.null(facets$labels) )
		facets$labels <- character(length(facets$plots))
	n <- length(facets$plots)
	# calculate the layout
	facets$dim <- get_dim(n, facets$dim, nrow, ncol)
	facets$drop <- drop
	facets$free <- free
	structure(facets, class="vizi_facets")
}

as_facets <- function(plotlist, ..., nrow = NA, ncol = NA,
	labels = NULL, drop = TRUE, free = "")
{
	# create plot list
	if ( missing(plotlist) || is.null(plotlist) )
		plotlist <- list()
	if ( inherits(plotlist, c("vizi_plot", "vizi_facets")) )
		plotlist <- list(plotlist)
	plotlist <- c(plotlist, list(...))
	# check all plots
	all_plots <- all(vapply(plotlist, is, logical(1L), "vizi_plot"))
	all_facets <- all(vapply(plotlist, is, logical(1L), "vizi_facets"))
	if ( !all_plots && !all_facets )
		matter_error("all plots must inherit from one of 'vizi_plot' or 'vizi_facets")
	if ( is.null(labels) ) {
		labels <- names(plotlist)
	} else {
		labels <- rep_len(labels, length(plotlist))
	}
	if ( all_plots ) {
		# combine vizi-plots
		if ( is.null(labels) )
			labels <- character(length(plotlist))
		plots <- lapply(plotlist,
			function(plot) {
				structure(list(
					encoding=plot$encoding,
					marks=plot$marks), class="vizi_plot")
			})
	} else {
		# combine vizi-facets
		if ( is.null(labels) ) {
			labels <- lapply(plotlist, function(p) character(length(p$plots)))
		} else {
			labels <- paste0(labels, "\n")
		}
		labels <- Map(function(lab, f) paste0(lab, f$labels), labels, plotlist)
		labels <- unlist(labels)
		plots <- lapply(plotlist, function(f) f$plots)
		plots <- unlist(plots, recursive=FALSE)
	}
	# inherit coord and params
	coord <- plotlist[[1L]]$coord
	params <- plotlist[[1L]]$params
	# merge channels and return facets
	channels <- lapply(plotlist, function(plot) plot$channels)
	channels <- do.call(merge_channels, unname(channels))
	dim <- get_dim(length(plots), nrow=nrow, ncol=ncol)
	facets <- list(plots=plots, channels=channels, coord=coord,
		params=params, subscripts=NULL, labels=labels,
		dim=dim, drop=drop, free=free)
	structure(facets, class="vizi_facets")
}

merge_facets <- function(plot1, plot2)
{
	# check all plots
	if ( !(is(plot1, "vizi_plot") && is(plot2, "vizi_plot")) &&
		!(is(plot1, "vizi_facets") && is(plot2, "vizi_facets")) )
	{
		matter_error("all plots must inherit from one of 'vizi_plot' or 'vizi_facets")
	}
	# merge channels
	channels <- merge_channels(plot1$channels, plot2$channels)
	if ( is(plot1, "vizi_plot") ) {
		# merge vizi-plots
		marks <- c(plot1$marks, plot2$marks)
		encoding <- merge_encoding(plot1$encoding, plot2$encoding)
		structure(list(encoding=encoding, channels=channels, marks=marks,
			coord=plot1$coord, params=plot1$params), class="vizi_plot")
	} else {
		# merge vizi-facets
		labels <- union(plot1$labels, plot2$labels)
		plots <- vector("list", length(labels))
		for ( i in seq_along(labels) ) {
			p1 <- plot1$plots[which(plot1$labels %in% labels[i])]
			p2 <- plot2$plots[which(plot2$labels %in% labels[i])]
			m1 <- lapply(p1, function(p) p$marks)
			m2 <- lapply(p2, function(p) p$marks)
			marks <- unlist(c(m1, m2), recursive=FALSE)
			e1 <- lapply(p1, function(p) p$encoding)
			e2 <- lapply(p2, function(p) p$encoding)
			encoding <- do.call(merge_encoding, c(e1, e2))
			plots[[i]] <- structure(list(
				encoding=encoding,
				marks=marks), class="vizi_plot")
		}
		dim <- get_dim(length(plots))
		structure(list(plots=plots, channels=channels, coord=plot1$coord,
			params=plot1$params, subscripts=NULL, labels=labels,
			dim=dim, drop=plot1$drop, free=plot1$free), class="vizi_facets")
	}
}

as_layers <- function(plotlist, ...)
{
	# create plot list
	if ( missing(plotlist) || is.null(plotlist) )
		plotlist <- list()
	if ( inherits(plotlist, c("vizi_plot", "vizi_facets")) )
		plotlist <- list(plotlist)
	plotlist <- c(plotlist, list(...))
	do.call(combine, plotlist)
}

set_title <- function(plot, title)
{
	plot$title <- as.character(title)
	plot
}

set_channel <- function(plot, channel, label = NULL,
	limits = NULL, scheme = NULL, key = TRUE)
{
	channel <- to_vizi_name(channel)
	ch <- plot$channels[[channel]]
	if ( is.null(ch) )
		ch <- list()
	if ( !is.null(label) )
		ch$label <- label
	if ( !is.null(limits) )
		ch$limits <- limits
	if ( !is.null(scheme) )
		ch$scheme <- scheme
	if ( !missing(key) )
		ch$key <- key
	plot$channels[[channel]] <- ch
	plot
}

set_coord <- function(plot,
	xlim = NULL, ylim = NULL, zlim = NULL,
	rev = "", log = "", asp = NA, grid = TRUE)
{
	co <- plot$coord
	if ( is.null(co) )
		co <- list()
	if ( !is.null(xlim) )
		co$xlim <- xlim
	if ( !is.null(ylim) )
		co$ylim <- ylim
	if ( !is.null(zlim) )
		co$zlim <- zlim
	if ( !missing(log) )
		co$log <- log
	if ( !missing(rev) )
		co$rev <- rev
	if ( !missing(asp) )
		co$asp <- asp
	if ( !missing(grid) )
		co$grid <- grid
	plot$coord <- co
	plot
}

set_par <- function(plot, ..., style = NULL)
{
	if ( ...length() > 0L )
		plot$params <- par_update(plot$params, ...)
	if ( !is.null(style) )
		plot$params <- par_update(plot$params, more=par_style(style))
	plot
}

set_engine <- function(plot, engine = c("base", "plotly"))
{
	plot$engine <- match.arg(engine)
	plot
}

# register for S4 methods

setOldClass("vizi_plot")
setOldClass("vizi_facets")
setOldClass("vizi_key")
setOldClass("vizi_colorkey")

setMethod("combine", c("vizi_plot", "vizi_plot"),
	function(x, y, ...) merge_facets(x, y))

setMethod("combine", c("vizi_facets", "vizi_facets"),
	function(x, y, ...) merge_facets(x, y))

setMethod("c", "vizi_plot", function(x, ...)
{
	if ( ...length() > 0 )
		x <- do.call(combine, list(x, ...))
	if ( validObject(x) )
		x
})

setMethod("c", "vizi_facets", function(x, ...)
{
	if ( ...length() > 0 )
		x <- do.call(combine, list(x, ...))
	if ( validObject(x) )
		x
})

#### Plotting methods for 'vizi' ####
## ----------------------------------

plot_init <- function(plot = NULL, ..., more = list(), n = 1L)
{
	args <- list(...)
	args <- par_update(args, more=more)
	names(args) <- lapply(names(args), to_par_name)
	# get x/y limits
	if ( is.null(args$xlim) )
		args$xlim <- plot$coord$xlim
	if ( is.null(args$ylim) )
		args$ylim <- plot$coord$ylim
	if ( is.null(args$xlim) )
		args$xlim <- plot$channels$x$limits
	if ( is.null(args$ylim) )
		args$ylim <- plot$channels$y$limits
	if ( has_floored_x(plot, args$xlim) )
		args$xlim <- floor_limits(args$xlim, 0)
	if ( has_floored_y(plot, args$ylim) )
		args$ylim <- floor_limits(args$ylim, 0)
	# check plotting engine
	e <- plot$engine
	if ( e$name == "plotly" )
	{
		# initialize plotly
		if ( is.null(e$plotly) )
			plot$engine$plotly <- plotly::plot_ly()
		# setup axes
		xlab <- plot$channels$x$label
		ylab <- plot$channels$y$label
		if ( is_discrete(args$xlim) ) {
			xlim <- NULL
		} else {
			xlim <- args$xlim + 0.01 * c(-1, 1) * diff(range(args$xlim))
		}
		if ( is_discrete(args$ylim) ) {
			ylim <- NULL
		} else {
			ylim <- args$ylim + 0.01 * c(-1, 1) * diff(range(args$ylim))
		}
		# check for reversed axes
		if ( !is.null(plot$coord$rev) )
		{
			if ( plot$coord$rev %in% c("x", "xy", "yx") )
				xlim <- rev(xlim)
			if ( plot$coord$rev %in% c("y", "xy", "yx") )
				ylim <- rev(ylim)
		}
		xaxis <- list(range=xlim, title=list(text=xlab))
		yaxis <- list(range=ylim, title=list(text=ylab))
		# check aspect ratio
		if ( !is.na(plot$coord$asp) )
		{
			yscale <- list(scaleanchor="x", scaleratio=plot$coord$asp)
			yaxis <- c(yaxis, yscale)
		}
		# initialize axes
		e$plotly <- plotly::layout(e$plotly, xaxis=xaxis, yaxis=yaxis)
		return()
	}
	# convert discrete axes
	if ( is_discrete(args$xlim) )
		args$xlim <- c(0.5, length(args$xlim) + 0.5)
	if ( is_discrete(args$ylim) )
		args$ylim <- c(0.5, length(args$ylim) + 0.5)
	if ( is2d(plot) ) {
		# get x/y aspect ratio and scale
		if ( is.null(args$log) )
			args$log <- plot$coord$log
		if ( is.null(args$asp) )
			args$asp <- plot$coord$asp
		# check for reversed axes
		if ( !is.null(plot$coord$rev) )
		{
			if ( plot$coord$rev %in% c("x", "xy", "yx") )
				args$xlim <- rev(args$xlim)
			if ( plot$coord$rev %in% c("y", "xy", "yx") )
				args$ylim <- rev(args$ylim)
		}
		# filter for valid graphical parameters
		winargs <- c("xlim", "ylim", "log", "asp")
		pars <- setdiff(names(par(no.readonly=TRUE)), winargs)
		winargs <- args[intersect(names(args), winargs)]
		pars <- args[intersect(names(args), pars)]
		# initialize the 2d plot
		plot.new()
		do.call(plot.window, winargs)
		par(pars)
		# add annotations
		if ( has_free_x(plot) || is_bottom_panel(n) ) {
			xl <- plot$channels$x$limits
			if ( is_discrete(xl) ) {
				Axis(args$xlim, side=1L, at=seq_along(xl), labels=xl)
			} else {
				Axis(args$xlim, side=1L)
			}
		}
		if ( has_free_y(plot) || is_left_panel() ) {
			yl <- plot$channels$y$limits
			if ( is_discrete(yl) ) {
				Axis(args$ylim, side=2L, at=seq_along(yl), labels=yl)
			} else {
				Axis(args$ylim, side=2L)
			}
		}
		if ( isTRUE(plot$coord$grid) )
			grid()
	} else {
		# get z limits
		if ( is.null(args$zlim) )
			args$zlim <- plot$coord$zlim
		if ( is.null(args$zlim) )
			args$zlim <- plot$channels$z$limits
		if ( length(unique(args$zlim)) <= 1L )
			args$zlim <- c(-1, 1) + args$zlim
		# get x/y/z labels
		if ( is.null(args$xlab) )
			args$xlab <- plot$channels$x$label
		if ( is.null(args$ylab) )
			args$ylab <- plot$channels$y$label
		if ( is.null(args$zlab) )
			args$zlab <- plot$channels$z$label
		# initialize the 3d plot
		args$x <- args$xlim
		args$y <- args$ylim
		args$z <- matrix(args$zlim, nrow=2L, ncol=2L)
		args$col <- NA
		args$border <- NA
		VT <- do.call(persp, args)
		trans3d_set(VT)
	}
}

is2d <- function(plot) {
	isFALSE("z" %in% names(plot$channels))
}

# preplot methods

preplot.vizi_plot <- function(object, ...)
{
	p <- vizi_par()
	p <- c(p, object$params[names(object$params) %in% names(p)])
	w <- needs_legends(object)
	if ( w > 0L )
		p <- par_pad(p, "right", w + 1L, outer=TRUE)
	panel_grid(dim=c(1L,1L), params=p)
	plot_init(object, more=par_update(object$params, ...), n=1L)
}

preplot.vizi_facets <- function(object, ...)
{
	p <- vizi_par()
	p <- c(p, object$params[names(object$params) %in% names(p)])
	w <- needs_legends(object)
	if ( w > 0L )
		p <- par_pad(p, "right", w + 1L, outer=TRUE)
	if ( has_free_x(object) || has_free_y(object) )
	{
		if ( has_free_x(object) ) {
			p <- par_pad(p, "bottom", 1)
			p <- par_pad(p, "bottom", -1, outer=TRUE)
		}
		if ( has_free_y(object) ) {
			p <- par_pad(p, "left", 1)
			p <- par_pad(p, "left", -1, outer=TRUE)
		}
		if ( is.null(p$bty) || p$bty == "n" )
			p$bty <- "l"
	}
	if ( is.null(object$labels) ) {
		n <- 1L
	} else {
		n <- max(nlines(object$labels))
	}
	p <- par_pad(p, "top", n - 1)
	panel_grid(dim=object$dim, params=p)
}

setMethod("preplot", "vizi_plot", preplot.vizi_plot)
setMethod("preplot", "vizi_facets", preplot.vizi_facets)

# plot methods

plot.vizi_plot <- function(x, add = FALSE, ..., engine = NULL)
{
	if ( !is.null(engine) )
		x$engine <- engine
	if ( is.null(x$engine) )
		x$engine <- getOption("matter.vizi.engine")
	if ( is.character(x$engine) || !add )
	{
		if ( is.character(x$engine) ) {
			name <- x$engine
		} else {
			name <- x$engine$name
		}
		x$engine <- new.env()
		x$engine$name <- name
	}
	# setup plot
	if ( x$engine$name == "base" && !add )
	{
		dev.hold()
		on.exit(dev.flush())
		preplot(x, ...)
		box()
	}
	if ( x$engine$name == "plotly" )
	{
		if ( !requireNamespace("plotly") )
			matter_error("failed to load required package 'plotly'")
		if ( !add )
			plot_init(x, more=par_update(x$params, ...))
	}
	# plot marks
	keys <- list()
	for ( i in seq_along(x$marks) )
	{
		mark <- x$marks[[i]]
		keys[[i]] <- plot(mark, plot=x, ...)
	}
	# add annotations
	keys <- merge_legends(keys)
	if ( !add )
	{
		if ( x$engine$name == "base" )
		{
			# add figure titles
			if ( is2d(x) ) {
				title(xlab=x$channels$x$label, outer=TRUE)
				title(ylab=x$channels$y$label, outer=TRUE)
			}
			if ( !is.null(x$title) )
				title(main=x$title, outer=TRUE)
			# add legends
			if ( length(keys) > 0L ) {
				p <- panel_side("right", split=length(keys), p=c(1, 1))
				for (key in keys)
					plot(key, cex=p$cex)
				panel_restore(p)
			}
			panel_set(new=FALSE)
		}
		if ( x$engine$name == "plotly" )
		{
			if ( !is.null(x$title) )
				x$engine$plotly <- plotly::layout(x$engine$plotly,
					title=list(text=x$title))
			print(x$engine$plotly)
		}
	}
	x$keys <- keys
	invisible(x)
}

plot.vizi_facets <- function(x, add = FALSE, ..., engine = NULL)
{
	if ( !is.null(engine) )
		x$engine <- engine
	if ( is.null(x$engine) )
		x$engine <- getOption("matter.vizi.engine")
	if ( is.character(x$engine) || !add )
	{
		if ( is.character(x$engine) ) {
			name <- x$engine
		} else {
			name <- x$engine$name
		}
		x$engine <- new.env()
		x$engine$name <- name
	}
	# setup facets
	n <- length(x$plots)
	if ( x$engine$name == "base" )
	{
		if ( !add ) {
			dev.hold()
			on.exit(dev.flush())
			preplot(x, ...)
		} else {
			panel_set(1)
		}
	}
	if ( x$engine$name == "plotly" )
	{
		if ( !requireNamespace("plotly") )
			matter_error("failed to load required package 'plotly'")
		if ( is.null(x$engine$facets) )
			x$engine$facets <- vector("list", length=n)
	}
	# loop through facets
	attr <- c("channels", "coord", "params", "engine")
	keys <- list()
	for ( i in seq_len(n) )
	{
		plot <- x$plots[[i]]
		plot[attr] <- x[attr]
		if ( !add )
		{
			# initialize plot
			xlim <- x$coord$xlim
			ylim <- x$coord$ylim
			if ( is.null(xlim) ) {
				if ( has_free_x(x) ) {
					xlim <- get_var_range(plot, "x")
				} else {
					xlim <- x$channels$x$limits
				}
			}
			if ( is.null(ylim) ) {
				if ( has_free_y(x) ) {
					ylim <- get_var_range(plot, "y")
				} else {
					ylim <- x$channels$y$limits
				}
			}
			params <- par_update(x$params, ...)
			plot_init(x, xlim=xlim, ylim=ylim, more=params, n=n)
			# fix subplot aspect ratio
			if ( x$engine$name == "plotly" && !is.na(x$coord$asp) )
			{
				if ( i == 1L ) {
					xanchor <- "x"
				} else {
					xanchor <- paste0("x", i)
				}
				yaxis <- list(scaleanchor=xanchor, scaleratio=plot$coord$asp)
				x$engine$plotly <- plotly::layout(x$engine$plotly, yaxis=yaxis)
			}
		}
		keys[[i]] <- plot(plot, add=TRUE, ...)$keys
		# add facet annotations
		if ( !add )
		{
			if ( x$engine$name == "base" )
				mtext(x$labels[i], cex=par("cex"), col=par("col.lab"))
			if ( x$engine$name == "plotly" )
			{
				x$engine$plotly <- plotly::add_annotations(x$engine$plotly,
					x=0.5, y=1, xanchor="center", yanchor="top",
					xref="paper", yref="paper", showarrow=FALSE,
					text=x$labels[i])

				x$engine$facets[[i]] <- plot$engine$plotly
				x$engine$plotly <- NULL
			}
		}
		if ( x$engine$name == "base" && add )
			panel_next()
	}
	# add figure annotations
	keys <- merge_legends(keys)
	if ( !add )
	{
		if ( x$engine$name == "base" )
		{
			# add figure titles
			if ( is2d(plot) ) {
				xlab_offset <- ifelse(has_free_x(x), 0.5, 1.5)
				ylab_offset <- ifelse(has_free_y(x), 0.5, 1.5)
				title(xlab=x$channels$x$label,
					line=xlab_offset, outer=TRUE)
				title(ylab=x$channels$y$label,
					line=ylab_offset, outer=TRUE)
			}
			if ( !is.null(x$title) )
				title(main=x$title, outer=TRUE)
			# add legends
			if ( length(keys) > 0L ) {
				p <- panel_side("right", split=length(keys), p=c(1, 1))
				for (key in keys)
					plot(key, cex=p$cex)
				panel_restore(p)
			}
			panel_set(new=FALSE)
		}
		if ( x$engine$name == "plotly" )
		{
			if ( !is.null(x$title) )
				x$engine$plotly <- plotly::layout(x$engine$plotly,
					title=list(text=x$title))
			print(plotly::subplot(x$engine$facets, nrows=x$dim[1L],
				shareX=!has_free_x(x), shareY=!has_free_y(x)))
		}
	}
	x$keys <- keys
	invisible(x)
}

setMethod("plot", "vizi_plot", plot.vizi_plot)
setMethod("plot", "vizi_facets", plot.vizi_facets)

print.vizi_plot <- plot.vizi_plot
print.vizi_facets <- plot.vizi_facets

setMethod("show", "vizi_plot", function(object) print.vizi_plot(object))
setMethod("show", "vizi_facets", function(object) print.vizi_facets(object))

plot.vizi_key <- function(x, cex = 1, ...)
{
	plot.new()
	args <- list(x="left", bty="n", title.adj=0, cex=cex)
	args <- c(args, x)
	valid <- names(args) %in% names(formals(legend))
	do.call(legend, args[valid])
}

plot.vizi_colorkey <- function(x, cex = 1, p = c(1/3, 2/3), ...)
{
	plt <- par("plt")
	p <- rep_len(p, 2L)
	dp <- (1 - p[2]) / 2
	pltnew <- c(0, p[1], dp, 1 - dp)
	par(plt=pltnew)
	col <- add_alpha(x$color, x$alpha)
	image(1, x$values, t(x$values), col=col, cex=cex,
		xaxt="n", yaxt="n", xlab="", ylab="")
	mtext(x$title, side=3L, cex=cex)
	Axis(x$values, side=4L, las=1L, cex.axis=cex)
	par(plt=plt)
}

setMethod("plot", "vizi_key", plot.vizi_key)
setMethod("plot", "vizi_colorkey", plot.vizi_colorkey)

#### Graphical parameters for vizi ####
## ------------------------------------

vizi_par <- function(..., style = getOption("matter.vizi.style"))
{
	params <- getOption("matter.vizi.par")
	if ( !is.null(style) ) {
		p <- par_style(tolower(style), new=TRUE)
		params <- par_update(params, more=p)
	}
	args <- list(...)
	if ( length(args) > 0L ) {
		if ( length(args) == 1L ) {
			if ( is.list(args[[1L]]) && is.null(names(args)) ) {
				args <- args[[1L]]
			} else if ( is.null(args[[1L]]) ) {
				args <- par_style_new()
				params <- list()
			}
		}
		if ( !is.null(names(args)) ) {
			params <- par_update(params, more=args)
			options(matter.vizi.par=params)
			return(invisible(params))
		}
		args <- as.character(unlist(args))
	} else {
		args < names(params)
	}
	if ( length(args) > 0L )
		params <- params[args]
	if ( length(params) == 1L )
		params <- params[[1L]]
	params
}

vizi_style <- function(style = "light", dpal = "Tableau 10", cpal = "Viridis")
{
	if ( !missing(style) ) {
		style <- match.arg(style, names(par_style_options()))
		options(matter.vizi.style=style)
	} else {
		style <- getOption("matter.vizi.style")
	}
	if ( !missing(dpal) ) {
		tryCatch(dpal(dpal)(1L), error=function(e)
			matter_error("palette must be one of ", paste0(palette.pals(), collapse=", ")))
		options(matter.vizi.dpal=dpal)
	} else {
		dpal <- getOption("matter.vizi.dpal")
	}
	if ( !missing(cpal) ) {
		tryCatch(cpal(cpal)(1L), error=function(e)
			matter_error("palette must be one of ", paste0(hcl.pals(), collapse=", ")))
		options(matter.vizi.cpal=cpal)
	} else {
		cpal <- getOption("matter.vizi.cpal")
	}
	style <- c(style=style, dpal=dpal, cpal=cpal)
	if ( nargs() > 0L ) {
		invisible(style)
	} else {
		style
	}
}

vizi_engine <- function(engine = c("base", "plotly"))
{
	if ( !missing(engine) ) {
		engine <- match.arg(engine)
		options(matter.vizi.engine=engine)
	} else {
		engine <- getOption("matter.vizi.engine")
	}
	if ( nargs() > 0L ) {
		invisible(engine)
	} else {
		engine
	}
}

#### Internal functions for vizi ####
## ----------------------------------

as_encoding <- function(x, y, ..., env = NULL)
{
	args <- list(...)
	if ( !missing(y) )
		args <- c(list(y=y), args)
	if ( !missing(x) )
		args <- c(list(x=x), args)
	args <- args[!vapply(args, is.null, logical(1L))]
	encoding <- lapply(args, function(e)
	{
		if ( is(e, "formula") && !is.null(env) )
			environment(e) <- env
		e
	})
	normalize_encoding(encoding)
}

normalize_encoding <- function(e)
{
	if ( length(e) > 0L ) {
		set_names(e, to_vizi_name(names(e)))
	} else {
		NULL
	}
}

to_par_name <- function(ch)
{
	channels <- c(shape = "pch", size = "cex",
		color = "col", colour = "col", fill = "bg",
		linewidth = "lwd", linetype = "lty",
		lineend = "lend", linejoin = "ljoin",
		linemitre = "lmitre")
	ifelse(ch %in% names(channels), channels[ch], ch)
}

to_vizi_name <- function(ch)
{
	channels <- c(pch = "shape", cex = "size",
		col = "color", colour = "color", fg = "color", bg = "fill",
		lwd = "linewidth", lty = "linetype",
		lend = "lineend", ljoin = "linejoin",
		lmitre = "linemitre")
	ifelse(ch %in% names(channels), channels[ch], ch)
}

merge_encoding <- function(e1, e2, ...)
{
	if ( missing(e2) )
		return(e1)
	if ( ...length() > 0L )
		e2 <- do.call(merge_encoding, list(e2, ...))
	if ( !is.null(e1) && !is.null(e2) ) {
		e <- e1
		for ( nm in names(e2) ) {
			# merge e2 into e1 => e2 takes priority
			e[[nm]] <- e2[[nm]]
		}
	} else if ( is.null(e1) && !is.null(e2) ) {
		e <- e2
	} else if ( !is.null(e1) && is.null(e2) ) {
		e <- e1
	} else {
		e <- NULL
	}
	e
}

merge_channels <- function(c1, c2, ...)
{
	if ( missing(c2) )
		return(c1)
	if ( ...length() > 0L )
		c2 <- do.call(merge_channels, list(c2, ...))
	chs <- list()
	nms <- union(names(c1), names(c2))
	for ( nm in nms ) {
		if ( nm %in% names(c1) && !nm %in% names(c2) ) {
			chs[[nm]] <- c1[[nm]]
		} else if ( !nm %in% names(c1) && nm %in% names(c2) ) {
			chs[[nm]] <- c2[[nm]]
		} else {
			ch <- c1[[nm]]
			for ( m in names(c2[[nm]]) ) {
				# merge c2 into c1 => c2 takes priority
				ch[[m]] <- c2[[nm]][[m]]
			}
			ch$limits <- merge_limits(c1[[nm]]$limits, c2[[nm]]$limits)
			chs[[nm]] <- ch
		}
	}
	chs
}

merge_limits <- function(l1, l2, ...)
{
	if ( missing(l2) )
		return(l1)
	if ( ...length() > 0L )
		l2 <- do.call(merge_limits, list(l2, ...))
	if ( is_discrete(l1) && is_discrete(l2) ) {
		union(l1, l2)
	} else if ( !is_discrete(l1) && !is_discrete(l2) ) {
		range(l1, l2, na.rm=TRUE)
	} else {
		if ( all(is.na(l1)) ) {
			l2
		} else if ( all(is.na(l2)) ) {
			l1
		} else {
			matter_error("can't merge continuous and discrete channels")
		}
	}
}

compute_variables <- function(encoding, data = NULL)
{
	f <- function(x) {
		x <- get_var(x, data)
		if ( is_discrete(x) ) {
			as.factor(x)
		} else {
			x
		}
	}
	e <- lapply(encoding, f)
	normalize_lengths(e)
}

compute_properties <- function(encoding, data = NULL)
{
	e <- compute_variables(encoding, data=data)
	xnames <- c("x", "xmin", "xmax", "xref")
	ynames <- c("y", "ymin", "ymax", "yref")
	nms <- names(e)
	channels <- lapply(nms, function(nm)
	{
		z <- encoding[[nm]]
		if ( is(z, "formula") ) {
			lab <- deparse1(z[[2L]])
		} else if ( is.character(z) && !is.null(data) ) {
			lab <- z[1L]
		} else {
			if ( nm %in% xnames ) {
				lab <- "x"
			} else if ( nm %in% ynames ) {
				lab <- "y"
			} else {
				lab <- nm
			}
		}
		lim <- get_limits(e[[nm]])
		list(label=lab, limits=lim)
	})
	nms <- replace(nms, nms %in% xnames, "x")
	nms <- replace(nms, nms %in% ynames, "y")
	names(channels) <- nms
	if ( anyDuplicated(nms) )
	{
		chs <- lapply(seq_along(nms), function(i) channels[i])
		channels <- do.call(merge_channels, chs)
	}
	list(encoding=e, channels=channels)
}

compute_subscripts <- function(by, nshingles = 6L)
{
	lapply(by, function(v) {
		if ( is_discrete(v) ) {
			v <- as.factor(v)
			nms <- levels(v)
			v <- lapply(levels(v), function(lvl) which(v == lvl))
			set_names(v, nms)
		} else {
			shingles(v, breaks=nshingles)
		}
	})
}

merge_subscripts <- function(subscripts, ...)
{
	if ( ...length() > 0L )
		subscripts <- list(subscripts, ...)
	ij <- expand.grid(lapply(subscripts, seq_along))
	fsub <- function(i) {
		i <- Map(function(F, j) F[[j]], subscripts, i)
		Reduce(intersect, i)
	}
	apply(ij, 1L, fsub, simplify=FALSE)
}

compute_facets <- function(plot, by, nshingles = 6L)
{
	n <- unique(lengths(by))
	if ( length(n) > 1L )
		matter_error("'by' has differing numbers of observations")
	subscripts <- compute_subscripts(by, nshingles)
	if ( length(subscripts) == 1L ) {
		dim <- panel_dim_n(prod(lengths(subscripts)))
	} else {
		dim <- c(lengths(subscripts)[c(2, 1)])
	}
	levels <- expand.grid(lapply(subscripts, names))
	labels <- apply(levels, 1L, paste0, collapse="\n")
	ffac <- function(v, p) {
		fsub <- function(x) {
			if ( length(x) != n ) {
				matter_error("faceting expected ", n, " observations ",
					"but encoding has ", length(x), "observations")
			} else {
				x[v]
			}
		}
		e <- lapply(p$encoding, fsub)
		mks <- lapply(p$marks, function(mk) {
			mk$encoding <- lapply(mk$encoding, fsub)
			mk
		})
		structure(list(encoding=e, marks=mks), class="vizi_plot")
	}
	subscripts <- merge_subscripts(subscripts)
	if ( is(plot, "vizi_facets") ) {
		plots <- lapply(plot$plots, function(p) lapply(subscripts, ffac, p=p))
		plots <- unlist(plots, recursive=FALSE)
		dim <- c(length(subscripts), length(plot$subscripts))
		subscripts <- merge_subscripts(plot$subscripts, subscripts)
		labels <- expand.grid(plot$labels, labels)
		labels <- apply(labels, 1L, paste0, collapse="\n")
	} else {
		plots <- lapply(subscripts, ffac, p=plot)
	}
	list(plots=plots, channels=plot$channels, coord=plot$coord,
		params=plot$params, subscripts=subscripts, labels=labels,
		dim=dim)
}

compute_groups <- function(plot, encoding, names)
{
	names <- names[names %in% names(encoding)]
	names <- names[!duplicated(encoding[names])]
	names <- set_names(names, names)
	groups <- lapply(plot$channels[names],
		function(ch) {
			if ( is_discrete(ch$limits) ) {
				ch$limits
			} else {
				NULL
			}
		})
	expand.grid(groups[non_null(groups)])
}

has_alpha <- function(plot)
{
	isTRUE("alpha" %in% names(plot$channels))
}

has_free_x <- function(plot)
{
	isTRUE(plot$free %in% c("x", "xy", "yx"))
}

has_free_y <- function(plot)
{
	isTRUE(plot$free %in% c("y", "xy", "yx"))
}

has_floored_x <- function(plot, x)
{
	!is_discrete(x) && any(c("bars") %in% names(plot$marks))
}

has_floored_y <- function(plot, y)
{
	!is_discrete(y) && any(c("bars", "peaks") %in% names(plot$marks))
}

get_dim <- function(n, dim, nrow = NA, ncol = NA)
{
	if ( missing(dim) )
		dim <- panel_dim_n(n)
	if ( !is.na(nrow) && !is.na(ncol) ) {
		dim[1L] <- nrow
		dim[2L] <- ncol
	} else if ( !is.na(nrow) ) {
		dim[1L] <- nrow
		dim[2L] <- ceiling(n / nrow)
	} else if ( !is.na(ncol) ) {
		dim[1L] <- ceiling(n / ncol)
		dim[2L] <- ncol
	}
	dim
}

get_var <- function(x, data)
{
	if ( is(x, "formula") ) {
		if ( length(x) != 2L )
			matter_error("formula encodings can only have rhs")
		eval(x[[2L]], envir=data, enclos=environment(x))
	} else {
		force(x)
	}
}

encode_var <- function(name, encoding = NULL,
	channels = NULL, params = NULL, subscripts = NULL)
{
	e <- encoding[[name]]
	if ( is.null(e) ) {
		# search plot parameters
		e <- params[[name]]
		# check for alpha channel
		if ( is.null(e) )
			e <- switch(name, alpha=1, NULL)
		# search graphical parameters
		pname <- to_par_name(name)
		# search vizi par
		if ( is.null(e) && pname %in% names(vizi_par()) )
		{
			e <- vizi_par(to_par_name(name))
		}
		# search base par
		if ( is.null(e) && dev.cur() != 1L &&
			pname %in% names(par(no.readonly=TRUE)) )
		{
			e <- par(to_par_name(name))
		}
	} else {
		# encode atomic variables
		if ( is.atomic(e) )
		{
			# encode limits
			lim <- channels[[name]]$limits
			if ( is.null(lim) )
				lim <- get_limits(e)
			e <- encode_limits(e, lim)
			# encode scheme
			sch <- channels[[name]]$scheme
			if ( is.null(sch) )
				sch <- get_scheme(name, e)
			e <- encode_scheme(e, sch, lim)
		}
		# subscripts
		if ( !is.null(subscripts) )
			e <- e[subscripts]
	}
	e
}

get_var_range <- function(plot, channel)
{
	if ( is.null(plot$encoding[[channel]]) ) {
		rc <- numeric()
	} else {
		rc <- range(plot$encoding[[channel]], na.rm=TRUE)
	}
	if ( is(plot, "vizi_plot") ) {
		rs <- unlist(lapply(plot$marks,
			function(mk) {
				if ( is.null(mk$encoding[[channel]]) ) {
					numeric()
				} else {
					range(mk$encoding[[channel]], na.rm=TRUE)
				}
			}))
	} else {
		rs <- unlist(lapply(plot$plots, get_var_range, channel))
	}
	range(c(rc, rs))
}

get_limits <- function(x)
{
	if ( is_discrete(x) ) {
		levels(as.factor(x))
	} else {
		if ( na_length(x, na.rm=TRUE) > 0L ) {
			range(x, na.rm=TRUE)
		} else {
			c(NA_real_, NA_real_)
		}
	}
}

floor_limits <- function(limits, include = 0)
{
	if ( max(limits) < include )
		limits[which.max(limits)] <- include
	if ( min(limits) > include )
		limits[which.min(limits)] <- include
	limits
}

encode_limits <- function(x, limits)
{
	if ( is.null(limits) )
		return(x)
	if ( is_discrete(x) ) {
		factor(as.factor(x), levels=limits)
	} else {
		ifelse(limits[1L] <= x & x <= limits[2L], x, NA)
	}
}

get_scheme <- function(channel, x)
{
	if ( is_discrete(x) ) {
		get_discrete_scheme(channel)
	} else {
		get_continuous_scheme(channel)
	}
}

get_discrete_scheme <- function(channel)
{
	msg <- paste0("can't make discrete scheme for ", sQuote(channel))
	switch(channel,
		x = , xmin = , xmax = ,
		y = , ymin = , ymax = ,
		z = ,
		text = NULL,
		shape = seq_fun(14),
		color = discrete_pal,
		fill = discrete_pal,
		alpha = matter_error(msg),
		size = matter_error(msg),
		linewidth = matter_error(msg),
		linetype = seq_fun(6),
		matter_error(msg))
}

get_continuous_scheme <- function(channel)
{
	msg <- paste0("can't make continuous scheme for ", sQuote(channel))
	switch(channel,
		x = , xmin = , xmax = ,
		y = , ymin = , ymax = ,
		z = ,
		text = NULL,
		shape = matter_error(msg),
		color = continuous_pal,
		fill = continuous_pal,
		alpha = range_fun(0, 1),
		size = range_fun(1, 6),
		linewidth = range_fun(1, 6),
		linetype = matter_error(msg),
		matter_error(msg))
}

discrete_pal <- function(n)
{
	palette.colors(n, getOption("matter.vizi.dpal"))
}

continuous_pal <- function(n)
{
	hcl.colors(n, getOption("matter.vizi.cpal"))
}

range_fun <- function(from, to, pow = 1) {
	function(n) seq.int(from, to, length.out=n)^pow
}

seq_fun <- function(max_n) {
	function(n) seq_len(min(n, max_n))
}

shape_pal <- function(n = 20L) {
	pal <- c(
		"circle" = 1L,
		"triangle point up" = 2L,
		"plus" = 3L,
		"cross" = 4L,
		"diamond" = 5L,
		"triangle point down" = 6L,
		"square cross" = 7L,
		"star" = 8L,
		"diamond plus" = 9L,
		"circle plus" = 10L,
		"triangles up and down" = 11L,
		"square plus" = 12L,
		"circle cross" = 13L,
		"square and triangle down" = 14L,
		"filled square" = 15L,
		"filled circle" = 16L,
		"filled triangle point-up" = 17L,
		"filled diamond" = 18L,
		"solid circle" = 19,
		"bullet" = 20L)
	if ( n > length(pal) )
		matter_error("n [", n, "] too large for shape palette")
	pal[seq_len(n)]
}

line_pal <- function(n = 6L) {
	pal <- c(
		"solid" = 1L,
		"dashed" = 2L,
		"dotted" = 3L,
		"dotdash" = 4L,
		"longdash" = 5L,
		"twodash" = 6L)
	if ( n > length(pal) )
		matter_error("n [", n, "] too large for line palette")
	pal[seq_len(n)]
}

encode_scheme <- function(x, scheme, limits)
{
	if ( is.null(scheme) )
		return(x)
	if ( is.function(scheme) ) {
		fx <- scheme
		if ( is_discrete(x) ) {
			n <- length(limits)
		} else {
			n <- 256L
		}
		scheme <- fx(n)
	}
	n <- length(scheme)
	if ( is_discrete(x) ) {
		if ( !is.factor(x) )
			x <- factor(x, levels=limits)
		scheme <- rep_len(scheme, nlevels(x))
	} else {
		dx <- diff(limits)
		if ( dx == 0 ) {
			x <- rep.int(1L, length(x))
		} else {
			breaks <- seq.int(limits[1L], limits[2L], length.out=n + 1L)
			breaks[1L] <- limits[1L] - (dx / 1000)
			breaks[n + 1L] <- limits[2L] + (dx / 1000)
			x <- cut.default(x, breaks=breaks)
		}
	}
	set_names(scheme[as.integer(x)], x)
}

encode_legends <- function(channels, params, type = NULL)
{
	keys <- list()
	ignore <- c("x", "y", "z", "text", "image")
	for ( nm in setdiff(names(channels), ignore) )
	{
		omit <- isFALSE(channels[[nm]]$key)
		if ( omit )
			next
		key <- params[!names(params) %in% nm]
		names(key) <- to_par_name(names(key))
		lab <- channels[[nm]]$label
		key$title <- lab
		# get limits
		lim <- channels[[nm]]$limits
		# get scheme
		sch <- channels[[nm]]$scheme
		if ( is.null(sch) )
			sch <- get_scheme(nm, lim)
		# make legend
		pnm <- to_par_name(nm)
		if ( is_discrete(lim) ) {
			key$legend <- lim
			key[[pnm]] <- encode_scheme(lim, sch, lim)
			class(key) <- "vizi_key"
		} else {
			if ( nm %in% c("color", "fill", "alpha") ) {
				# colormap key
				valmin <- lim[1L]
				valmax <- lim[2L]
				if ( valmin == valmax ) {
					valmin <- valmin - 1
					valmax <- valmax + 1
				}
				key$values <- seq.int(valmin, valmax, length.out=256L)
				if ( nm == "alpha" ) {
					key$color <- encode_var("color")
					key$alpha <- encode_scheme(key$values, sch, lim)
				} else {
					key$color <- encode_scheme(key$values, sch, lim)
					key$alpha <- encode_var("alpha")
				}
				class(key) <- "vizi_colorkey"
			} else {
				# standard key
				x <- seq.int(lim[1L], lim[2L], length.out=3L)
				key[[pnm]] <- encode_scheme(x, sch, lim)
				key$legend <- format(x)
				class(key) <- "vizi_key"
			}
		}
		if ( !is.null(type) )
		{
			if ( type %in% c("p", "b", "o") ) {
				if ( "bg" %in% names(key) )
					key$pt.bg <- key$bg
				if ( "cex" %in% names(key) )
					key$pt.cex <- key$cex
				if ( "lwd" %in% names(key) )
					key$pt.lwd <- key$lwd
				if ( type == "p" )
					key[c("bg", "cex", "lwd", "lty")] <- NULL
				if ( !"pch" %in% names(key) )
					key$pch <- encode_var("pch")
			}
			if ( type %in% c("l", "h") ) {
				key$pch <- NULL
				key$cex <- NULL
				if ( !"lty" %in% names(key) )
					key$lty <- encode_var("lty")
				if ( !"lwd" %in% names(key) )
					key$lwd <- encode_var("lwd")
			}
		} else if ( is(key, "vizi_key") ) {
			if ( !"pch" %in% names(key) ) {
				if ( !"bg" %in% names(key) )
					key$fill <- key$col
				if ( "bg" %in% names(key) )
					key$fill <- key$bg
				key$border <- NA
			}
		}
		if ( length(keys) > 0L && lab %in% names(keys) ) {
			keys[[lab]] <- merge_legends(keys[[lab]], key)[[1L]]
		} else {
			keys[[lab]] <- key
		}
	}
	keys
}

merge_legends <- function(keys, ...)
{
	if ( ...length() > 0L ) {
		keys <- list(keys, ...)
		names(keys) <- rep.int(".", length(keys))
	} else {
		keys <- do.call(c, unname(keys))
	}
	ks <- list()
	nms <- unique(names(keys))
	for ( nm in nms )
	{
		ks[[nm]] <- structure(list(), class=class(keys[[nm]]))
		for ( k in keys[names(keys) %in% nm] )
		{
			for ( p in names(k) )
			{
				replace <- length(k[[p]]) > length(ks[[nm]][[p]])
				if ( !p %in% names(ks[[nm]]) || replace )
					ks[[nm]][[p]] <- k[[p]]
			}
		}
		if ( "fill" %in% names(ks[[nm]]) )
			ks[[nm]][c("pch", "lty", "lwd")] <- NULL
	}
	ks
}

needs_legends <- function(plot)
{
	ignore <- c("x", "y", "z", "text", "image")
	chs <- names(plot$channels)
	chs <- setdiff(chs, ignore)
	chs <- plot$channels[chs]
	fn <- function(x) {
		if ( is.numeric(x) )
			x <- format(x)
		w <- strwidth(x, "in") / strheight(x, "in")
		max(2, w)
	}
	if ( length(chs) > 0L ) {
		nokey <- vapply(chs, function(ch) isFALSE(ch$key), logical(1L))
		lens1 <- vapply(chs, function(ch) fn(ch$limits), numeric(1L))
		lens2 <- vapply(chs, function(ch) fn(ch$label), numeric(1L))
		lens <- ifelse(nokey, 0, pmax(lens1, lens2))
		floor(max(lens, na.rm=TRUE))
	} else {
		FALSE
	}
}
