
#### Chunk-Apply classes ####
## ---------------------------

setClass("chunked",
	slots = c(
		data = "ANY",
		index = "list",
		verbose = "logical",
		drop = "logical_OR_NULL"),
	contains = "VIRTUAL",
	validity = function(object) {
		errors <- NULL
		if ( is.null(object@data) )
			errors <- c(errors, "'data' must not be NULL")
		index_ok <- vapply(object@index, is.numeric, logical(1L))
		if ( !all(index_ok) )
			errors <- c(errors, "'index' must be a list of numeric vectors")
		if ( is.logical(object@drop) && length(object@drop) != 1L )
			errors <- c(errors, "'drop' must be a scalar logical or NULL")
		if ( length(object@verbose) != 1L )
			errors <- c(errors, "'verbose' must be a scalar logical")
		if ( is.null(errors) ) TRUE else errors
	})

setClass("chunked_vec", contains = "chunked")

setClass("chunked_arr",
	slots = c(margin = "integer"),
	contains = "chunked")

setClass("chunked_mat", contains = "chunked_arr")

setClass("chunked_list", contains = "chunked")

chunked_vec <- function(x, nchunks = NA, chunksize = NA,
	verbose = FALSE, permute = FALSE, depends = NULL, drop = FALSE)
{
	if ( is.na(chunksize) ) {
		chunksize <- getOption("matter.default.chunksize")
	} else {
		chunksize <- as_size(chunksize)
	}
	if ( is.na(nchunks) ) {
		if ( is.finite(chunksize) && chunksize > 0 ) {
			f <- 1
			if ( is.numeric(permute) )
				f <- length(permute) / length(x)
			if ( is.list(permute) )
				f <- sum(lengths(permute)) / length(x)
			if ( inherits(chunksize, "size_bytes") ) {
				nchunks <- ceiling(f * unclass(mem_realized(x)) / chunksize)
			} else {
				nchunks <- ceiling(f * length(x) / chunksize)
			}
		} else {
			nchunks <- getOption("matter.default.nchunks")
		}
	}
	index <- chunkify(seq_along(x), nchunks=nchunks,
		permute=permute, depends=depends)
	new("chunked_vec", data=x, index=index,
		verbose=verbose, drop=drop)
}

chunked_mat <- function(x, margin, nchunks = NA, chunksize = NA,
	verbose = FALSE, permute = FALSE, depends = NULL, drop = FALSE)
{
	if ( length(dim(x)) != 2L )
		matter_error("'x' must have exactly 2 dimensions")
	if ( !margin %in% c(1L, 2L) )
		matter_error("'margin' must be 1 or 2")
	if ( is.na(chunksize) ) {
		chunksize <- getOption("matter.default.chunksize")
	} else {
		chunksize <- as_size(chunksize)
	}
	if ( is.na(nchunks) ) {
		if ( is.finite(chunksize) && chunksize > 0 ) {
			f <- 1
			if ( is.numeric(permute) )
				f <- length(permute) / dim(x)[margin]
			if ( is.list(permute) )
				f <- sum(lengths(permute)) / dim(x)[margin]
			if ( inherits(chunksize, "size_bytes") ) {
				nchunks <- ceiling(f * unclass(mem_realized(x)) / chunksize)
			} else {
				nchunks <- ceiling(f * dim(x)[margin] / chunksize)
			}
		} else {
			nchunks <- getOption("matter.default.nchunks")
		}
	}
	margin <- as.integer(margin)
	index <- switch(margin,
		chunkify(seq_len(nrow(x)), nchunks=nchunks,
			permute=permute, depends=depends),
		chunkify(seq_len(ncol(x)), nchunks=nchunks,
			permute=permute, depends=depends))
	new("chunked_mat", data=x, margin=margin, index=index,
		verbose=verbose, drop=drop)
}

chunked_list <- function(..., nchunks = NA, chunksize = NA,
	verbose = FALSE, permute = FALSE, depends = NULL, drop = FALSE)
{
	xs <- list(...)
	if ( length(xs) > 1L ) {
		len <- vapply(xs, length, integer(1L))
		if ( n_unique(len) != 1L ) {
			max.len <- max(len)
			if ( max.len && any(len == 0L) )
				matter_error("zero-length and non-zero length inputs cannot be mixed")
			if ( any(max.len %% len) )
				matter_warn("longer argument not a multiple of length of vector")
			xs <- lapply(xs, rep_len, length.out=max.len)
		}
	}
	if ( is.na(chunksize) ) {
		chunksize <- getOption("matter.default.chunksize")
	} else {
		chunksize <- as_size(chunksize)
	}
	if ( is.na(nchunks) ) {
		if ( is.finite(chunksize) && chunksize > 0 ) {
			f <- 1
			if ( is.numeric(permute) )
				f <- length(permute) / length(xs[[1L]])
			if ( is.list(permute) )
				f <- sum(lengths(permute)) / length(xs[[1L]])
			if ( inherits(chunksize, "size_bytes") ) {
				nchunks <- ceiling(f * unclass(mem_realized(xs)) / chunksize)
			} else {
				nchunks <- ceiling(f * length(xs[[1L]]) / chunksize)
			}
		} else {
			nchunks <- getOption("matter.default.nchunks")
		}
	}
	index <- chunkify(seq_along(xs[[1L]]), nchunks=nchunks,
		permute=permute, depends=depends)
	new("chunked_list", data=xs, index=index,
		verbose=verbose, drop=drop)
}

setAs("chunked", "list", function(from) from[])

setMethod("as.list", "chunked", function(x) as(x, "list"))

setMethod("describe_for_display", "chunked", function(x) {
	desc1 <- paste0("<", length(x), " length> ", class(x))
	desc2 <- paste0(class(x@data)[1L], " chunks")
	paste0(desc1, " :: ", desc2)
})

setMethod("preview_for_display", "chunked",
	function(x) preview_list(x))

setMethod("preview_for_display", "chunked_list",
	function(x) preview_recursive(x))

setMethod("show", "chunked", function(object) {
	cat(describe_for_display(object), "\n", sep="")
	n <- getOption("matter.show.head.n")
	if ( getOption("matter.show.head") )
		try(preview_for_display(object), silent=TRUE)
	cat("with", sum(lengths(object@index)), "total items\n")
})

setMethod("vm_used", "chunked", function(x) vm_used(x@data))

setMethod("shm_used", "chunked", function(x) shm_used(x@data))

setMethod("mem_realized", "chunked", function(x) mem_realized(x@data))

setMethod("length", "chunked", function(x) length(x@index))

setMethod("lengths", "chunked", function(x) lengths(x@index))

setMethod("[",
	c(x = "chunked", i = "ANY", j = "ANY", drop = "ANY"),
	function(x, i, ..., drop = TRUE)
	{
		if ( ...length() > 0 )
			matter_error("incorrect number of dimensions")
		i <- as_subscripts(i, x)
		if ( is.null(i) )
			i <- seq_along(x)
		if ( is_null_or_na(drop) ) {
			y <- new(class(x), x, index=x@index[i])
		} else {
			y <- vector("list", length(i))
			for ( j in seq_along(i) )
				y[[j]] <- x[[i[j]]]
		}
		y
	})

setMethod("[[", c(x = "chunked_list"),
	function(x, i, j, ..., exact = TRUE) {
		i <- as_subscripts(i, x)
		y <- lapply(x@data, `[`, x@index[[i]], drop=x@drop)
		attr(y, "chunkinfo") <- attributes(x@index[[i]])
		if ( x@verbose )
			print_chunk_progress(y)
		y
	})

setMethod("[[", c(x = "chunked_vec"),
	function(x, i, j, ..., exact = TRUE) {
		i <- as_subscripts(i, x)
		y <- x@data[x@index[[i]],drop=x@drop]
		attr(y, "chunkinfo") <- attributes(x@index[[i]])
		if ( x@verbose )
			print_chunk_progress(y)
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
		if ( x@verbose )
			print_chunk_progress(y)
		y
	})

drop_from_BPPARAM <- function(X, BPPARAM, chunkopts = list())
{
	serialize <- get_serialize(chunkopts)
	if ( is.na(serialize) )
		serialize <- getOption("matter.default.serialize")
	if ( isTRUE(serialize) ) {
		drop <- FALSE
	} else if ( isFALSE(serialize) ) {
		drop <- NULL
	} else {
		if ( isFALSE(has_matter_data(X)) || is.null(BPPARAM) ) {
			drop <- FALSE
		} else if ( isTRUE(bplocal(BPPARAM)) ) {
			drop <- NULL
		} else {
			drop <- FALSE
		}
	}
	drop
}

matter_log_chunk_init <- function(x, verbose) {
	matter_log("# processing ", length(x), " chunks ",
		"(~", sum(lengths(x)) %/% length(x), " items per chunk ",
		"| ~", format(mem_realized(x) / length(x)), " per chunk",
		")", verbose=verbose)
}

matter_log_chunk_exit <- function(x, verbose) {
	matter_log("# collecting ", sum(lengths(x)), " results ",
		"from ", length(x), " chunks", verbose=verbose)
}

print_chunk_progress <- function(x) {
	info <- attr(x, "chunkinfo")
	if ( is.list(x) ) {
		sizes <- vapply(x, mem_realized, numeric(1L))
		size <- format(size_bytes(sum(sizes, na.rm=TRUE)))
	} else {
		if ( is.matter(x) ) {
			size <- format(size_bytes(mem_realized(x)))
		} else {
			size <- format(size_bytes(object.size(x)))
		}
	}
	message("# processing chunk ",
		info$chunkid, "/", info$nchunks,
		" (", info$chunklen, " items | ", size, ")")
}

chunkify <- function(x, nchunks = 20L, permute = FALSE, depends = NULL)
{
	if ( !is.null(depends) && length(depends) != length(x) )
		matter_error("length of 'depends' must match extent of 'x'")
	if ( isTRUE(permute) ) {
		index <- sample.int(length(x))
	} else if ( isFALSE(permute) ) {
		index <- seq_along(x)
	} else {
		index <- permute
	}
	if ( is.list(index) ) {
		if ( nchunks > 1L ) {
			nchunks <- min(ceiling(lengths(index) / 2L), nchunks)
			index <- lapply(index, function(i) split(i, cut(i, nchunks)))
			index <- do.call(Map, c(list(base::c), index))
		} else {
			index <- list(unlist(index))
		}
	} else {
		nchunks <- min(ceiling(length(index) / 2L), nchunks)
		if ( nchunks > 1L ) {
			index <- split(index, cut(seq_along(index), nchunks))
		} else {
			index <- list(index)
		}
	}
	index <- unname(index)
	ans <- vector("list", length(index))
	for ( i in seq_along(index) )
	{
		if ( !is.null(depends) ) {
			di <- depends[index[[i]]]
			ind <- c(index[[i]], unlist(di))
			ind <- sort(unique(ind))
			if ( any(ind < 1L | ind > length(x)) )
				matter_error("'depends' subscript out of bounds")
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
		attr(ans[[i]], "chunklen") <- n
		attr(ans[[i]], "nchunks") <- nchunks
	}
	names(ans) <- names(x)
	ans
}
