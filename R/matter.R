
#### VIRTUAL 'matter' class ####
## ------------------------------

setClass("matter",
	slots = c(
		data = "ANY",
		type = "factor",
		dim = "numeric_OR_NULL",
		names = "character_OR_NULL",
		dimnames = "list_OR_NULL"),
	contains = "VIRTUAL",
	validity = function(object) {
		errors <- NULL
		if ( anyNA(object@type) )
			errors <- c(errors, "'type' must not contain missing values")
		if ( !is.null(object@names) && length(object@names) != length(object) )
			errors <- c(errors, paste0("names [length ", length(object@names), "] ",
				"do not match length of object [", length(object), "]"))
		if ( !is.null(dimnames) && is.null(dim) )
			errors <- c(errors, "'dimnames' applied to non-array")
		if ( !is.null (object@dimnames) )
		{
			if ( is.null(object@dim) )
				errors <- c(errors, "'dimnames' applied to non-array")
			if ( length(object@dimnames) != length(object@dim) )
				errors <- c(errors, paste0("length of 'dimnames' [", length(object@dimnames), "] ",
					"must match that of 'dims' [", length(object@dim), "]"))
			for ( i in seq_along(object@dimnames) )
			{
				dmn <- object@dimnames[[i]]
				if ( !is.null(dmn) && length(dmn) != object@dim[i] )
					errors <- c(errors, paste0("length of 'dimnames' [", i, "] ",
						"not equal to array extent"))
			}
		}
		if ( is.null(errors) ) TRUE else errors
	})

setMethod("show", "matter", function(object) {
	cat(describe_for_display(object), "\n", sep="")
	if ( getOption("matter.show.head") )
		try(preview_for_display(object), silent=TRUE)
})

matter <- function(data, ...) {
	if ( !missing(data) && is.matter(data) )
		data <- data[]
	nm <- ...names()
	arg_vec <- c("length", "names")
	arg_mat <- c("nrow", "ncol")
	arg_arr <- c("dim", "dimnames")
	arg_list <- c("lengths")
	arg_fct <- c("levels", "labels")
	arg_str <- c("nchar")
	known_args <- c(arg_arr, arg_mat, arg_vec,
		arg_fct, arg_list, arg_str)
	if ( any(nm %in% known_args) ) {
		if ( any(arg_vec %in% nm) ) {
			matter_vec(data, ...)
		} else if ( any(arg_mat %in% nm) ) {
			matter_mat(data, ...)
		} else if ( any(arg_arr %in% nm) ) {
			matter_arr(data, ...)
		} else if ( any(arg_list %in% nm) ) {
			matter_list(data, ...)
		} else if ( any(arg_fct %in% nm) ) {
			matter_fct(data, ...)
		} else if ( any(arg_str %in% nm) ) {
			matter_str(data, ...)
		} else {
			matter_error("cannot guess data structure, use 'matter_*' functions")
		}
	} else {
		if ( is.vector(data) && is.raw(data) ) {
			matter_vec(data, ...)
		} else if ( is.vector(data) && is.logical(data) ) {
			matter_vec(data, ...)
		} else if ( is.vector(data) && is.numeric(data) ) {
			matter_vec(data, ...)
		} else if ( is.matrix(data) ) {
			matter_mat(data, ...)
		} else if ( is.array(data) ) {
			matter_arr(data, ...)
		} else if ( is.list(data) ) {
			matter_list(data, ...)
		} else if ( is.factor(data) ) {
			matter_fct(data, ...)
		} else if ( is.vector(data) &&  is.character(data) ) {
			matter_str(data, ...)
		} else {
			matter_error("cannot make 'matter' object from class ",
				sQuote(class(data)))
		}
	}
}

is.matter <- function(x) {
	is(x, "matter")
}

as.matter <- function(x) {
	if ( is.matter(x) ) {
		return(x)
	} else {
		matter(x)
	}
}

is.shared <- function(x) {
	is(x, "matter_") && all(is_shared_memory_pattern(path(x)))
}

as.shared <- function(x) {
	if ( is.shared(x) ) {
		return(x)
	} else {
		matter(x, path=":memory:")
	}
}

has_matter_data <- function(X) {
	is(X, "matter_") || 
		(is(X, "matter") && is.matter(atomdata(X))) ||
		(is(X, "matter") && is.matter(atomindex(X)))
}

setMethod("adata", "matter",
	function(object, ...) atomdata(object, ...))

setMethod("atomdata", "matter",
	function(object, ...) object@data)

setReplaceMethod("atomdata", "matter", function(object, ..., value) {
	object@data <- value
	if ( validObject(object) )
		object
})

setMethod("aindex", "matter",
	function(object, ...) NULL)

setMethod("atomindex", "matter",
	function(object, ...) NULL)

setMethod("type", "matter", function(x) x@type)

setReplaceMethod("type", "matter", function(x, value) {
	x@type <- as_Rtype(value)
	if ( validObject(x) )
		x
})

setMethod("length", "matter", function(x) prod(x@dim))

setMethod("dim", "matter", function(x) x@dim)

setReplaceMethod("dim", "matter", function(x, value) {
	if ( prod(x@dim) != prod(value) )
		matter_error("dims [product ", prod(value), "] do not match ",
			"the length of object [", prod(x@dim), "]")
	x@dim <- value
	x@dimnames <- NULL
	if ( validObject(x) )
		x
})

setMethod("names", "matter", function(x) x@names)

setReplaceMethod("names", "matter", function(x, value) {
	if ( !is.null(value) )
		value <- as.character(value)
	x@names <- value
	if ( validObject(x) )
		x
})

setMethod("dimnames", "matter", function(x) x@dimnames)

setReplaceMethod("dimnames", "matter", function(x, value) {
	if ( !is.null(value) )
		value <- lapply(value, function(v) if(!is.null(v)) as.character(v))
	x@dimnames <- value
	if ( validObject(x) )
		x
})

#### VIRTUAL 'matter_' class for virtual memory data ####
## ------------------------------------------------------

setClass("matter_",
	slots = c(
		data = "atoms",
		type = "factor",
		dim = "numeric_OR_NULL",
		names = "character_OR_NULL",
		dimnames = "list_OR_NULL"),
	contains = c("VIRTUAL", "matter"))

setMethod("describe_for_display", "ANY", function(x) class(x))

setMethod("preview_for_display", "ANY", function(x) head(x))

setMethod("vm_used", "matter_", function(x) vm_used(atomdata(x)))

setMethod("shm_used", "matter_", function(x) shm_used(atomdata(x)))

setMethod("show", "matter_", function(object) {
	callNextMethod()
	show_matter_mem(object)
})

setMethod("path", "matter_", function(object, ...) path(object@data))

setReplaceMethod("path", "matter_",
	function(object, ..., value) {
		path(object@data) <- value
		object
	})

setMethod("readonly", "matter_", function(x) readonly(x@data))

setReplaceMethod("readonly", "matter_",
	function(x, value) {
		readonly(x@data) <- value
		x
	})

setMethod("checksum", "matter_",
	function(x, algo = "sha1", ...) {
		checksum(path(x), algo=algo, ...)
	})

