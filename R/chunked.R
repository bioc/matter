
#### Chunk-Apply classes ####
## ---------------------------

setClass("chunked",
	slots = c(
		data = "ANY",
		index = "list",
		drop = "logical_OR_NULL"),
	contains = "VIRTUAL",
	validity = function(object) {
		errors <- NULL
		if ( is.null(object@data) )
			errors <- c(errors, "'data' must not be NULL")
		index_ok <- vapply(object@index, is.numeric, logical(1L))
		if ( !all(index_ok) )
			errors <- c(errors, "'index' must be a list of numeric vectors")
		if ( !is.null(object@drop) && length(object@drop) != 1L )
			errors <- c(errors, "'drop' must be a scalar logical or NULL")
		if ( is.null(errors) ) TRUE else errors
	})

setClass("chunked_vec", contains = "chunked")

setClass("chunked_arr",
	slots = c(margin = "integer"),
	contains = "chunked")

setClass("chunked_mat", contains = "chunked_arr")

setClass("chunked_list", contains = "chunked")

setAs("chunked", "list", function(from) from[])

setMethod("as.list", "chunked", function(x) as(x, "list"))

setMethod("describe_for_display", "chunked", function(x) {
	desc1 <- paste0("<", length(x), " length> ", class(x))
	desc2 <- paste0(class(x@data)[1L], " chunks")
	paste0(desc1, " :: ", desc2)
})

setMethod("preview_for_display", "chunked", function(x) preview_list(x))

setMethod("show", "chunked", function(object) {
	cat(describe_for_display(object), "\n", sep="")
	n <- getOption("matter.show.head.n")
	if ( getOption("matter.show.head") )
		try(preview_for_display(object), silent=TRUE)
	cat("with", sum(lengths(object@index)), "total items\n")
})

setMethod("length", "chunked", function(x) length(x@index))

setMethod("lengths", "chunked", function(x) lengths(x@index))

setMethod("[",
	c(x = "chunked", i = "ANY", j = "ANY", drop = "ANY"),
	function(x, i, ..., drop = TRUE)
	{
		if ( ...length() > 0 )
			stop("incorrect number of dimensions")
		i <- as_subscripts(i, x)
		if ( is_null_or_na(drop) ) {
			if ( is.null(i) ) {
				if ( is.null(dim(x@data)) ) {
					new(class(x),
						data=x@data,
						index=x@index[i],
						drop=x@drop)
				} else {
					new(class(x),
						data=x@data,
						index=x@index[i],
						drop=x@drop,
						margin=x@margin)
				}
			} else {
				x
			}
		} else {
			if ( is.null(i) )
				i <- seq_along(x)
			ans <- vector("list", length(i))
			for ( j in seq_along(i) )
				ans[[j]] <- x[[i[j]]]
			ans
		}
	})

chunked_vec <- function(x, nchunks = NA,
	depends = NULL, drop = FALSE)
{
	if ( is.na(nchunks) )
		nchunks <- getOption("matter.default.nchunks")
	index <- chunkify(seq_along(x), nchunks=nchunks, depends=depends)
	new("chunked_vec", data=x,
		index=index, drop=drop)
}

chunked_mat <- function(x, margin, nchunks = NA,
	depends = NULL, drop = FALSE)
{
	if ( length(dim(x)) != 2L )
		stop("'x' must have exactly 2 dimensions")
	if ( !margin %in% c(1L, 2L) )
		stop("'margin' must be 1 or 2")
	if ( is.na(nchunks) )
		nchunks <- getOption("matter.default.nchunks")
	margin <- as.integer(margin)
	index <- switch(margin,
		chunkify(seq_len(nrow(x)), nchunks=nchunks, depends=depends),
		chunkify(seq_len(ncol(x)), nchunks=nchunks, depends=depends))
	new("chunked_mat", data=x, margin=margin,
		index=index, drop=drop)
}

chunked_list <- function(..., nchunks = NA,
	depends = NULL, drop = FALSE)
{
	xs <- list(...)
	if ( length(xs) > 1L ) {
		len <- vapply(xs, length, integer(1L))
		if ( n_unique(len) != 1L ) {
			max.len <- max(len)
			if ( max.len && any(len == 0L) )
				stop("zero-length and non-zero length inputs cannot be mixed")
			if ( any(max.len %% len) )
				warning("longer argument not a multiple of length of vector")
			xs <- lapply(xs, rep_len, length.out=max.len)
		}
	}
	if ( is.na(nchunks) )
		nchunks <- getOption("matter.default.nchunks")
	index <- chunkify(seq_along(xs[[1L]]), nchunks=nchunks, depends=depends)
	new("chunked_list", data=xs,
		index=index, drop=drop)
}

setMethod("[[", c(x = "chunked_list"),
	function(x, i, j, ..., exact = TRUE) {
		i <- as_subscripts(i, x)
		y <- lapply(x@data, `[`, x@index[[i]], drop=x@drop)
		attr(y, "chunkinfo") <- attributes(x@index[[i]])
		y
	})

setMethod("[[", c(x = "chunked_vec"),
	function(x, i, j, ..., exact = TRUE) {
		i <- as_subscripts(i, x)
		y <- x@data[x@index[[i]],drop=x@drop]
		attr(y, "chunkinfo") <- attributes(x@index[[i]])
		y
	})

setMethod("[[", c(x = "chunked_mat"),
	function(x, i, j, ..., exact = TRUE) {
		i <- as_subscripts(i, x)
		y <- switch(x@margin,
			x@data[x@index[[i]],,drop=x@drop],
			x@data[,x@index[[i]],drop=x@drop])
		attr(y, "chunkinfo") <- attributes(x@index[[i]])
		attr(y, "margin") <- x@margin
		y
	})

chunkify <- function(x, nchunks = 20L, depends = NULL) {
	if ( !is.null(depends) && length(depends) != length(x) )
		stop("length of 'depends' must match extent of 'x'")
	nchunks <- min(ceiling(length(x) / 2L), nchunks)
	index <- seq_along(x)
	if ( nchunks > 1L ) {
		index <- split(index, cut(index, nchunks))
	} else {
		index <- list(index)
	}
	ans <- vector("list", length(index))
	for ( i in seq_along(index) )
	{
		if ( !is.null(depends) ) {
			di <- depends[index[[i]]]
			ind <- c(index[[i]], unlist(di))
			ind <- sort(unique(ind))
			if ( any(ind < 1L | ind > length(x)) )
				stop("'depends' subscript out of bounds")
			dep <- lapply(di, match, ind)
			dep <- dep[match(ind, index[[i]])]
		} else {
			ind <- index[[i]]
			dep <- NULL
		}
		n <- length(index[[i]])
		ans[[i]] <- x[ind]
		attr(ans[[i]], "index") <- c(ind)
		attr(ans[[i]], "depends") <- c(dep)
		attr(ans[[i]], "chunkid") <- i
		attr(ans[[i]], "chunksize") <- n
		attr(ans[[i]], "nchunks") <- nchunks
	}
	names(ans) <- names(x)
	ans
}
