
#### 'deferred_ops' for deferred operations ####
## ----------------------------------------------

setClass("deferred_ops",
	slots = c(
		ops = "factor",  # deferred op codes (Arith/Math)
		arg = "list",
		rhs = "logical", # is the original object lhs or rhs?
		margins = "matrix", # [,1] = arg, [,2] = group
		group = "list"),
	validity = function(object) {
		errors <- NULL
		lens <- c(
			ops=length(object@ops),
			arg=length(object@arg),
			rhs=length(object@rhs),
			margins=nrow(object@margins),
			group=length(object@group))
		if ( n_unique(lens) != 1L )
			errors <- c(errors, paste0("lengths of ",
				"'ops' [", lens["ops"], "], ",
				"'arg' [", lens["arg"], "], ",
				"'rhs' [", lens["rhs"], "], ",
				"'margins' [", lens["margins"], "], ",
				"and 'group' [", lens["group"], "] ",
				"must all be equal"))
		if ( anyNA(object@ops) )
			errors <- c(errors, "'ops' can't have missing values")
		for ( i in seq_along(object@ops) ) {
			if ( !is.null(object@arg[[i]]) ) {
				if ( is.na(object@rhs[i]) )
					errors <- c(errors,
						"'rhs' can't be missing for non-NULL 'arg'")
				if ( is.na(object@margins[i,1]) )
					errors <- c(errors,
						"'margins' can't be missing for non-NULL 'arg'")
			}
			if ( !is.null(object@group[[i]]) ) {
				ugroup <- unique(object@group[[i]])
				ugroup <- ugroup[!is.na(ugroup)]
				if ( length(ugroup) != ncol(object@arg[[i]]) )
					errors <- c(errors,
						paste0("number of groups [", length(ugroup), "] ",
						"does not match ncol of 'arg'",
						" [", ncol(object@arg[[i]]), "]"))
				if ( any(ugroup < 0 | ugroup >= ncol(object@arg[[i]])) )
					errors <- c(errors,
						paste0("groups do not match ncol of 'arg'",
						" [", ncol(object@arg[[i]]), "]"))
				if ( is.na(object@margins[i,2]) )
					errors <- c(errors,
						"'margins' can't be missing for non-NULL 'group'")
			}
		}
		if ( is.null(errors) ) TRUE else errors
	})

append_op <- function(object, op, arg = NULL, rhs = FALSE,
	margins = rep.int(NA_integer_, 2), group = NULL)
{
	if ( !is.matrix(margins) )
		margins <- matrix(margins, ncol=2)
	if ( !is.null(group) ) {
		group <- as.integer(group)
		group <- group - min(group, na.rm=TRUE)
	}
	if ( is.null(object) ) {
		new("deferred_ops", ops=op, arg=list(arg), rhs=rhs,
			margins=margins, group=list(group))
	} else {
		object@ops <- c(object@ops, op)
		object@arg <- c(object@arg, list(arg))
		object@rhs <- c(object@rhs, rhs)
		object@margins <- rbind(object@margins, margins)
		object@group <- c(object@group, list(group))
		if ( validObject(object) )
			object
	}
}

register_op <- function(x, op, arg = NULL, rhs = FALSE)
{
	op <- as_Ops(op)
	if ( !is.null(arg) && !is.numeric(arg) && !is.logical(arg) )
		matter_error("arguments must be numeric or logical")
	if ( is.null(arg) ) {
		margin <- NA_integer_
	} else if ( is.null(dim(x)) || is.null(dim(arg)) ) {
		margin <- 1L
		if ( is.null(dim(arg)) && !is.null(dim(x)) ) {
			dm <- rep_len(1L, length(dim(x)))
			dm[1L] <- length(arg)
			dim(arg) <- dm
		}
	} else {
		if ( rhs ) {
			rdim <- dim(x)
			ldim <- dim(arg)
		} else {
			rdim <- dim(arg)
			ldim <- dim(x)
		}
		if ( length(ldim) != length(rdim) )
			matter_error("number of dimensions are not equal for ",
				"lhs [", length(ldim), "] and rhs [", length(rdim), "]")
		margin <- which(dim(arg) != 1L)
	}
	if ( length(margin) == 0L )
		margin <- 1L
	if ( length(margin) != 1L )
		matter_error("only a single dim of argument may be unequal to 1")
	if ( !is.null(arg) )
		arg <- as.vector(arg)
	xlen <- if (is.null(dim(x))) length(x) else dim(x)[margin]
	if ( !is.na(margin) && length(arg) != 1L ) {
		if ( rhs ) {
			rext <- xlen
			lext <- length(arg)
		} else {
			rext <- length(arg)
			lext <- xlen
		}
		if ( lext != rext )
			matter_error("extent of array is not equal for ",
				"lhs [", lext, "] and rhs [", rext, "]")
	}
	margins <- c(margin, NA_integer_)
	x@ops <- append_op(x@ops, op=op, arg=arg, rhs=rhs, margins=margins)
	x@type <- as_Rtype("double")
	if ( validObject(x) )
		x
}

register_group_op <- function(x, op, arg, group,
	rhs = FALSE, margins = rep.int(NA_integer_, 2))
{
	op <- as_Ops(op)
	if ( !is.null(arg) && !is.numeric(arg) && !is.logical(arg) )
		matter_error("arguments must be numeric or logical")
	xlen1 <- if (is.null(dim(x))) length(x) else dim(x)[margins[1L]]
	if ( rhs ) {
		rext <- xlen1
		lext <- nrow(arg)
	} else {
		rext <- nrow(arg)
		lext <- xlen1
	}
	if ( lext != rext )
		matter_error("extent of array is not equal for ",
			"lhs [", lext, "] and rhs [", rext, "]")
	xlen2 <- if (is.null(dim(x))) length(x) else dim(x)[margins[2L]]
	if ( xlen2 != length(group) )
		matter_error("length of groups [", length(group),
			" are not equal to array extent [", xlen2, "]")
	x@ops <- append_op(x@ops, op=op, arg=arg,
		rhs=rhs, margins=margins, group=group)
	x@type <- as_Rtype("double")
	if ( validObject(x) )
		x
}

subset_op <- function(ops, k, index)
{
	if ( length(ops@arg[[k]]) > 1L )
	{
		for ( j in seq_along(index) )
		{
			if ( is.null(index[[j]]) ) {
				next
			} else {
				i <- index[[j]]
			}
			if ( isTRUE(ops@margins[k,1L] == j) )
			{
				if ( is.null(dim(ops@arg)) ) {
					ops@arg[[k]] <- ops@arg[[k]][i]
				} else {
					ops@arg[[k]] <- ops@arg[[k]][i,,drop=FALSE]
				}
			}
			if ( isTRUE(ops@margins[k,2L] == j) )
				ops@group[[k]] <- ops@group[[k]][i]
		}
	}
	ops
}

subset_ops <- function(ops, index)
{
	if ( !is.null(ops) )
	{
		for ( k in seq_along(ops@ops) )
			ops <- subset_op(ops, k, index)
	}
	ops
}

t_op <- function(ops, k)
{
	if ( length(ops@arg[[k]]) > 1L )
	{
		margin <- ops@margins[k,]
		if ( margin[1L] %in% c(1L, 2L) )
			ops@margins[k,1L] <- switch(margin[1L], 2L, 1L)
		if ( margin[2L] %in% c(1L, 2L) )
			ops@margins[k,2L] <- switch(margin[2L], 2L, 1L)
	}
	ops
}

t_ops <- function(ops)
{
	if ( !is.null(ops) )
	{
		for ( k in seq_along(ops@ops) )
			ops <- t_op(ops, k)
	}
	ops
}
