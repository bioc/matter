
#### Spatial Gaussian mixture model ####
## --------------------------------------

sgmix <- function(x, y, vals, r = 1, k = 2, group = NULL,
	weights = c("gaussian", "bilateral", "adaptive"),
	metric = "maximum", p = 2, neighbors = NULL,
	annealing = TRUE, niter = 10L, tol = 1e-3,
	compress = FALSE, byrow = FALSE,
	verbose = NA, chunkopts = list(),
	BPPARAM = bpparam(), ...)
{
	if ( is.na(verbose) )
		verbose <- getOption("matter.default.verbose")
	if ( is.array(x) && missing(y) && missing(vals) ) {
		if ( !is.matrix(x) && length(dim(x)) != 3L )
			matter_error("x must be 2D matrix or 3D array")
		co <- as.matrix(expand.grid(
			x=seq_len(nrow(x)),
			y=seq_len(ncol(x))))
		dm <- c(nrow(x), ncol(x))
		if ( is.matrix(x) ) {
			vals <- list(x)
		} else {
			vals <- array2list(x, 3L)
		}
	} else {
		co <- cbind(x, y)
		dm <- NULL
	}
	if ( is.list(vals) ) {
		n <- length(vals)
	} else if ( length(dim(vals)) == 2L ) {
		n <- if (byrow) nrow(vals) else ncol(vals)
	} else {
		matter_error("'vals' must be a list or matrix-like")
	}
	if ( n > 1 ) {
		matter_log("fitting spatial segmentations for ", n, " images", verbose=verbose)
		margin <- if (byrow) 1L else 2L
		if ( is.list(vals) ) {
			ans <- chunkLapply(vals, sgmix_int,
				coord=co, r=r, k=k, group=group,
				weights=weights, neighbors=neighbors,
				annealing=annealing, niter=niter, tol=tol,
				compress=compress, verbose=verbose, RNG=TRUE,
				chunkopts=chunkopts, BPPARAM=BPPARAM)
		} else {
			ans <- chunkApply(vals, margin, sgmix_int,
				coord=co, r=r, k=k, group=group,
				weights=weights, neighbors=neighbors,
				annealing=annealing, niter=niter, tol=tol,
				compress=compress, verbose=verbose, RNG=TRUE,
				chunkopts=chunkopts, BPPARAM=BPPARAM)
		}
	} else {
		if ( is.list(vals) )
			vals <- vals[[1L]]
		ans <- sgmix_int(vals,
			coord=co, r=r, k=k, group=group,
			weights=weights, neighbors=neighbors,
			annealing=annealing, niter=niter, tol=tol,
			compress=compress, verbose=verbose)
		ans <- list(ans)
	}
	group <- ans[[1L]]$group
	loglik <- simplify2array(lapply(ans, `[[`, "logLik"))
	kout <- vapply(ans, function(a) nlevels(droplevels(a$class)), integer(1L))
	if ( any(kout < k) )
		matter_warn("fewer than k classes for images ",
			paste0(which(kout != k), collapse=", "))
	pv <- simplify2array(lapply(ans, `[[`, "probability"))
	ans <- list(
		class=lapply(ans, `[[`, "class"),
		probability=structure(pv,
			group=attr(ans[[1L]]$probability, "group")),
		mu=simplify2array(lapply(ans, `[[`, "mu")),
		sigma=simplify2array(lapply(ans, `[[`, "sigma")),
		alpha=simplify2array(lapply(ans, `[[`, "alpha")),
		beta=simplify2array(lapply(ans, `[[`, "beta")))
	if ( !is.null(dm) ) {
		ans$class <- lapply(ans$class,
			function(class) {
				if ( !is.drle(class) ) {
					class <- as.integer(class)
					dim(class) <- dm
				}
				class
			})
	}
	if ( is.list(pv) && is.null(pv[[1L]]) )
		ans$probability <- NULL
	ans$group <- group
	ans$logLik <- loglik
	class(ans) <- c("sgmixn", "sgmix")
	ans
}

sgmixn <- function(x, y, vals, ...)
{
	.Deprecated("sgmix")
	sgmix(x=x, y=y, vals=vals, ...)
}

sgmix_int <- function(x, coord, r = 1, k = 2, group = NULL,
	weights = c("gaussian", "bilateral", "adaptive"),
	metric = "maximum", p = 2, neighbors = NULL,
	annealing = TRUE, niter = 10L, tol = 1e-3,
	compress = FALSE, verbose = NA, ...)
{
	if ( is.na(verbose) )
		verbose <- getOption("matter.default.verbose")
	if ( is.matrix(x) && missing(coord) ) {
		co <- as.matrix(expand.grid(
			x=seq_len(nrow(x)),
			y=seq_len(ncol(x))))
		dm <- c(nrow(x), ncol(x))
	} else {
		if ( missing(coord) ) {
			co <- NULL
			if ( !is.list(weights) && !is.list(neighbors) )
				matter_error("both 'weights' and 'neighbors' must be ",
					"specified when x/y coordinates are not")
		} else {
			co <- coord
		}
		dm <- NULL
	}
	x <- as.vector(x)
	xmin <- min(x, na.rm=TRUE)
	xmax <- max(x, na.rm=TRUE)
	# find neighboring pixels
	if ( is.null(neighbors) ) {
		nb <- kdsearch(co, co, tol=r)
		ds <- rowdist_at(co, ix=seq_len(nrow(co)), iy=nb, metric=metric, p=p)
		nb <- lapply(seq_along(x),
			function(i) {
				d_ok <- ds[[i]] <= r
				if ( is.null(group) ) {
					g_ok <- rep.int(TRUE, length(d_ok))
				} else {
					g_ok <- group[nb[[i]]] %in% group[i]
				}
				nb[[i]][d_ok & g_ok]
			})
	} else {
		nb <- rep_len(neighbors, length(x))
	}
	# find neighboring pixel weights
	if ( is.character(weights) ) {
		weights <- match.arg(weights)
		d2 <- rowdist_at(co, ix=seq_len(nrow(co)), iy=nb, metric="euclidean")
		a <- ((2 * r) + 1) / 4
		wts <- lapply(d2, function(d) exp(-d^2 / (2 * a^2)))
		if ( weights %in% c("bilateral", "adaptive") ) {
			d3 <- Map(function(xi, i) abs(xi - x[i]), x, nb)
			if ( weights == "bilateral" ) {
				bs <- rep_len(mad(x, na.rm=TRUE), length(x))
			} else {
				bs <- vapply(d3, function(d) (max(d) / 2)^2, numeric(1L))
			}
			awts <- Map(function(d, b) exp(-d^2 / (2 * b^2)), d3, bs)
			awts <- lapply(awts, function(w) replace(w, is.na(w), 1))
			wts <- Map("*", wts, awts)
		}
	} else {
		wts <- rep_len(weights, length(x))
	}
	wts <- lapply(wts, function(w) w / sum(w, na.rm=TRUE))
	# grouped segmentation
	if ( !is.null(group) )
	{
		# fit model for each group
		group <- as.factor(group)
		gs <- levels(group)
		ans <- lapply(gs, function(g)
			{
				matter_log("fitting model for group ", g, verbose=verbose)
				i <- which(group %in% g)
				nbi <- lapply(nb[i], bsearch, table=i)
				if ( is.character(weights) ) {
					sgmix_int(x[i], coord=co[i,,drop=FALSE], r=r, k=k,
						group=NULL, weights=weights, neighbors=nbi,
						annealing=annealing, niter=niter, tol=tol,
						compress=FALSE, verbose=verbose, ...)
				} else {
					sgmix_int(x[i], coord=co[i,,drop=FALSE], r=r, k=k,
						group=NULL, weights=wts[i], neighbors=nbi,
						annealing=annealing, niter=niter, tol=tol,
						compress=FALSE, verbose=verbose, ...)
				}
			})
		# combine and return models
		mu <- do.call(rbind, lapply(ans, `[[`, "mu"))
		sigma <- do.call(rbind, lapply(ans, `[[`, "sigma"))
		alpha <- do.call(rbind, lapply(ans, `[[`, "alpha"))
		beta <- unlist(lapply(ans, `[[`, "beta"))
		dimnames(mu) <- list(gs, seq_len(k))
		dimnames(sigma) <- dimnames(mu)
		dimnames(alpha) <- dimnames(mu)
		names(beta) <- gs
		y <- matrix(0, nrow=length(x), ncol=length(mu))
		for ( i in seq_along(gs) ) {
			ir <- which(group %in% gs[i])
			ic <- seq_len(k) + (i - 1L) * k
			y[ir,ic] <- ans[[i]]$probability
		}
		colnames(y) <- rep.int(seq_len(k), length(gs))
		attr(y, "group") <- rep(gs, each=k)
		class <- predict_class(y)
		if ( compress ) {
			class <- drle(class)
			y <- NULL
		}
		if ( !is.null(dm) && !is.drle(class) ) {
			class <- as.integer(class)
			dim(class) <- dm
		}
		loglik <- sum(unlist(lapply(ans, `[[`, "logLik")))
		ans <- list(class=class, probability=y,
			mu=mu, sigma=sigma, alpha=alpha, beta=beta)
		ans$group <- group
		ans$logLik <- loglik
		class(ans) <- "sgmix"
		return(ans)
	}
	# check for degeneracy
	xu <- sort(unique(x), decreasing=TRUE)
	if ( length(xu) <= k )
	{
		if ( length(xu) < k )
			matter_warn("k > number of distinct data points")
		class <- factor(x, levels=xu, labels=seq_along(xu))
		y <- encode_dummy(class)
		mu <- set_names(c(xu, rep.int(NA_real_, k - length(xu))), seq_len(k))
		sigma <- set_names(rep.int(0, k), seq_len(k))
		alpha <- set_names(rep.int(1, k), seq_len(k))
		ans <- list(class=class, probability=y, mu=t(mu), sigma=t(sigma),
			alpha=t(alpha), beta=1, logLik=NA_real_)
		class(ans) <- "sgmix"
		return(ans)
	}
	# initialize parameters (mu, sigma, alpha, beta)
	matter_log("initializing model using k-means", verbose=verbose)
	init <- kmeans(x, centers=k, ...)
	mu <- as.vector(init$centers)
	sigma <- as.vector(tapply(x, init$cluster, sd))
	sigma <- ifelse(is.finite(sigma), sigma, 0.15 * mu)
	alpha <- rep.int(1, k)
	beta <- 1
	# initialize p(x|mu,sigma)
	px <- matrix(0, nrow=length(x), ncol=k)
	for ( i in seq_len(k) )
		px[,i] <- (1 / sigma[i]) * exp(-(x - mu[i])^2 / (2 * sigma[i]^2))
	y <- px / rowSums(px)
	class <- predict_class(y)
	# expectation step
	stepE <- function(y, mu, sigma, alpha, beta, ...)
	{
		# compute posterior probability p(z|neighbors)
		ybar <- apply(y, 2L, convolve_at,
			index=nb, weights=wts, na.rm=TRUE)
		# update p(x|mu,sigma)
		px <- matrix(0, nrow=length(x), ncol=k)
		for ( i in seq_len(k) )
			px[,i] <- (1 / sigma[i]) * exp(-(x - mu[i])^2 / (2 * sigma[i]^2))
		px <- px / rowSums(px, na.rm=TRUE)
		# update prior probability
		priors <- t(alpha * t(ybar)^beta)
		priors <- priors / rowSums(priors, na.rm=TRUE)
		# update posterior probability p(z)
		y <- px * priors
		# compute log-likelihood
		loglik <- sum(log1p(rowSums(pmax(y, 0))), na.rm=TRUE)
		y <- y / rowSums(y, na.rm=TRUE)
		list(y=y, ybar=ybar, loglik=loglik)
	}
	# maximization step
	stepM <- function(eta, y, ybar, mu, sigma, alpha, beta, ...)
	{
		# initialize gradient
		gr <- list(
			mu=rep.int(1, k),
			sigma=rep.int(1, k),
			alpha=rep.int(1, k),
			beta=1)
		# compute gradient
		gr$mu <- rowSums(t(y) * (mu - rep(x, each=k)) / sigma^2, na.rm=TRUE)
		c1 <- 1 / sigma
		c2 <- (mu - rep(x, each=k))^2 / sigma^3
		gr$sigma <- rowSums(t(y) * (c1 - c2), na.rm=TRUE)
		c1 <- -rowSums(2 * t(y) / alpha, na.rm=TRUE)
		c2 <- colSums(y * ybar^beta, na.rm=TRUE)
		c3 <- rowSums(alpha^2 * t(ybar^beta), na.rm=TRUE)
		gr$alpha <- c1 + 2 * alpha * sum(c2 / c3)
		c1 <- alpha^2 * t(ybar^beta)
		c2 <- c1 * t(log1p(ybar))
		c3 <- colSums(c2, na.rm=TRUE) / colSums(c1, na.rm=TRUE)
		gr$beta <- sum(y * (-log1p(ybar) + c3), na.rm=TRUE)
		# find step size limits
		limits <- range(c(0, abs(sigma / gr$sigma),
			abs(alpha / gr$alpha), abs(beta / gr$beta)), na.rm=TRUE)
		# update parameters
		list(
			mu=mu - eta * gr$mu,
			sigma=sigma - eta * gr$sigma,
			alpha=alpha - eta * gr$alpha,
			beta=beta - eta * gr$beta,
			limits=limits)
	}
	# iterate
	tt <- 1
	matter_log("estimating parameters with gradient descent", verbose=verbose)
	for ( iter in seq_len(niter) )
	{
		# update probability from expectation step
		E <- stepE(y, mu=mu, sigma=sigma, alpha=alpha, beta=beta)
		ybar <- E$ybar
		y <- E$y
		loglik <- E$loglik
		if ( all(class == predict_class(y)) ) {
			matter_log("no more class assignment changes", verbose=verbose)
			break
		}
		class <- predict_class(y)
		# set up objective function
		fn <- function(eta, ...) {
			m <- stepM(eta, ...)
			e <- stepE(y, mu=m$mu, sigma=m$sigma, alpha=m$alpha, beta=m$beta)
			if ( is.finite(e$loglik) ) {
				-e$loglik
			} else {
				.Machine$double.xmax
			}
		}
		# find optimal gradient descent step size
		eta <- stepM(0, y=y, ybar=ybar,
			mu=mu, sigma=sigma, alpha=alpha, beta=beta)
		G <- optimize(fn, eta$limits, y=y, ybar=ybar,
			mu=mu, sigma=sigma, alpha=alpha, beta=beta)
		matter_log("log Lik = ", format.default(-G$objective), " on iteration ", iter,
			" (step size = ", format.default(G$minimum), ")", verbose=verbose)
		if ( annealing || loglik > -G$objective )
		{
			# simulate annealing
			i <- sample(k)
			sa_mu <- mu
			sa_mu[i] <- rnorm(1L, mean=mu[i], sd=tt * sigma[i])
			S <- stepE(y, mu=sa_mu, sigma=sigma, alpha=alpha, beta=beta)
			tt <- tt - (1 / niter)
			if ( S$loglik > -G$objective && S$loglik > loglik )
			{
				matter_log("log Lik = ",
					format.default(S$loglik), " on iteration ", iter,
					" (simulated annealing)", verbose=verbose)
				mu <- sa_mu
				next
			}
			if ( loglik > -G$objective ) {
				matter_log("log Lik decreased; reverting to previous model",
					verbose=verbose)
				break
			}
		}
		# update parameters from maximization step
		M <- stepM(G$minimum, y=y, ybar=ybar,
			mu=mu, sigma=sigma, alpha=alpha, beta=beta)
		if ( any(c(M$sigma, M$alpha, M$beta) <= 0) || 
			any(M$mu < xmin) || any(M$mu > xmax) )
		{
			matter_log("constraining parameters; reverting to previous model",
				verbose=verbose)
			break
		}
		mu <- M$mu
		sigma <- M$sigma
		alpha <- M$alpha
		beta <- M$beta
		if ( abs(-loglik - G$objective) < tol )
			break
	}
	# re-order based on segment means
	ord <- order(mu, decreasing=TRUE)
	y <- y[,ord,drop=FALSE]
	mu <- set_names(mu[ord], seq_len(k))
	sigma <- set_names(sigma[ord], seq_len(k))
	alpha <- set_names(alpha[ord], seq_len(k))
	# estimate final parameters and probabilities
	E <- stepE(y, mu=mu, sigma=sigma, alpha=alpha, beta=beta)
	y <- E$y
	colnames(y) <- seq_len(k)
	class <- predict_class(y)
	if ( compress ) {
		class <- drle(class)
		y <- NULL
	}
	if ( !is.null(dm) && !is.drle(class) ) {
		class <- as.integer(class)
		dim(class) <- dm
	}
	ans <- list(class=class, probability=y,
		mu=t(mu), sigma=t(sigma), alpha=t(alpha), beta=beta)
	ans$logLik <- loglik
	class(ans) <- "sgmix"
	ans
}

print.sgmix <- function(x, ...)
{
	cat(sprintf("Spatial Gaussian mixture model (k=%d, channels=%d)\n",
		ncol(x$mu), length(x$class)))
	if ( !is.null(x$group) )
		cat("\nGroups:", levels(x$group), "\n")
	cat("\nParameter estimates:\n")
	cat("$mu\n")
	preview_Nd_array(x$mu, ...)
	cat("\n$sigma\n")
	preview_Nd_array(x$sigma, ...)
	invisible(x)
}

fitted.sgmix <- function(object,
	type = c("mu", "sigma", "class"), channel = NULL, ...)
{
	type <- match.arg(type)
	if ( is.null(channel) ) {
		if ( type == "mu" ) {
			object$mu
		} else if ( type == "sigma" ) {
			object$sigma
		} else {
			object$class
		}
	} else {
		if ( type == "mu" ) {
			object$mu[,,channel]
		} else if ( type == "sigma" ) {
			object$sigma[,,channel]
		} else {
			object$class[[channel]]
		}
	}
}

logLik.sgmix <- function(object, ...)
{
	nobs <- lengths(object$class)
	p <- 3L * prod(dim(object$mu)[1:2]) + 1L
	structure(object$logLik, df=nobs - p, nobs=nobs,
		class="logLik")
}


