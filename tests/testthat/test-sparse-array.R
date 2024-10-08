require(testthat)
require(matter)

context("sparse-array")

test_that("sparse vector subsetting", {

	set.seed(1, kind="default")
	x <- rbinom(100, 1, 0.2)
	x[x != 0] <- seq_len(sum(x != 0))
	y <- sparse_vec(x)

	expect_equal(x, y[])
	expect_equal(x[1:10], y[1:10])
	expect_equal(x[10:1], y[10:1])
	expect_equal(x[c(NA,1:10,NA)], y[c(NA,1:10,NA)])
	expect_error(y[-1])
	expect_error(y[length(y) + 1])

	z <- y[1:50,drop=NULL]

	expect_is(z, "sparse_vec")
	expect_equal(x[1:50], z[])

	domain(y) <- seq_along(y) - 1L
	expect_equal(x, y[])
	expect_equal(x[1:10], y[1:10])
	expect_equal(x[10:1], y[10:1])

	atomindex(y) <- matter_vec(atomindex(y))
	atomdata(y) <- matter_vec(atomdata(y))
	expect_equal(x, y[])
	expect_equal(x[1:10], y[1:10])
	expect_equal(x[10:1], y[10:1])

	z <- sparse_vec(1:5, index=1:5)
	domain(z) <- seq(from=2, to=3, by=0.25)
	tolerance(z) <- 0.3
	expect_equal(c(2, 2, 0, 3, 3), z[])

})

test_that("sparse vector subsetting w/ interpolation", {

	z <- sparse_vec(index=c(1.0, 1.01, 1.11,
							2.0, 2.22,
							3.0, 3.33, 3.333,
							4.0),
					data=c(1.0, 1.01, 1.11,
							2.0, 2.22,
							3.0, 3.33, 3.333,
							4.0),
					domain=seq(from=0, to=4, by=0.5))

	test1 <- c(0, 0, 1, 0, 2, 0, 3, 0, 4)
	expect_equal(test1, z[])

	tolerance(z) <- 0.25
	test2 <- c(0, 0, 1, 0, 2, 0, 3, 3.333, 4)
	expect_equal(test2, z[])

	sampler(z) <- "sum"
	test3 <- c(0, 0, 1.0+1.01+1.11, 0, 2.0+2.22, 0, 3, 3.33+3.333, 4)
	expect_equal(test3, z[])

	sampler(z) <- "mean"
	test4 <- c(0, 0, (1.0+1.01+1.11)/3, 0, (2.0+2.22)/2, 0, 3, (3.33+3.333)/2, 4)
	expect_equal(test4, z[])

	sampler(z) <- "linear"
	tolerance(z) <- 1.0
	test5 <- c(1, 1, 1, 1.5, 2, 2.5, 3, 3.5, 4)
	expect_equal(test5, z[])

	z2 <- sparse_vec(index=rev(aindex(z)),
					data=rev(adata(z)),
					domain=domain(z))
	expect_equal(test1, z2[])

	z3 <- sparse_vec(index=seq_len(11),
					data=c(rep_len(1, 5), 10,
						rep_len(1, 5)),
					domain=seq_len(11))
	
	tolerance(z3) <- 2
	sampler(z3) <- "sum"
	test6 <- c(3, 4, 5, 14, 14, 14, 14, 14, 5, 4, 3)
	expect_equal(test6, z3[])

	sampler(z3) <- "mean"
	wts <- rep_len(1, 5)
	test7 <- filter(adata(z3), wts / sum(wts), circular=TRUE)
	expect_equal(as.vector(test7), z3[])

	sampler(z3) <- "gaussian"
	wts <- dnorm((-2):2)
	test8 <- filter(adata(z3), wts / sum(wts), circular=TRUE)
	expect_equal(as.vector(test8), z3[])

})

test_that("sparse matrix subsetting (csc)", {

	set.seed(1, kind="default")
	x <- rbinom(200, 1, 0.2)
	x[x != 0] <- seq_len(sum(x != 0))
	dim(x) <- c(20, 10)
	y <- sparse_mat(x)

	expect_equal(x, y[])
	expect_equal(x[,1], y[,1])
	expect_equal(x[1,], y[1,])
	expect_equal(x[,10], y[,10])
	expect_equal(x[20,], y[20,])
	expect_equal(x[1:10,1:5], y[1:10,1:5])
	expect_equal(x[10:1,5:1], y[10:1,5:1])
	expect_equal(x[11:20,6:10], y[11:20,6:10])
	expect_equal(x[,c(1,NA,10)], y[,c(1,NA,10)])
	expect_equal(x[c(1,NA,10),], y[c(1,NA,10),])
	expect_equal(x[1,,drop=FALSE], as.matrix(y[1,,drop=NULL]))
	expect_error(y[,-1])
	expect_error(y[-1,])
	expect_error(y[,ncol(y) + 1])
	expect_error(y[nrow(y) + 1,])

	z <- y[1:5,1:5,drop=NULL]

	expect_is(z, "sparse_mat")
	expect_equal(x[1:5,1:5], z[])

	y <- sparse_mat(x, pointers=TRUE)

	expect_equal(x, y[])
	expect_equal(x[,1], y[,1])
	expect_equal(x[1,], y[1,])
	expect_equal(x[,10], y[,10])
	expect_equal(x[20,], y[20,])
	expect_equal(x[1:10,1:5], y[1:10,1:5])
	expect_equal(x[10:1,5:1], y[10:1,5:1])
	expect_equal(x[11:20,6:10], y[11:20,6:10])
	expect_equal(x[,c(1,NA,10)], y[,c(1,NA,10)])
	expect_equal(x[c(1,NA,10),], y[c(1,NA,10),])
	expect_error(y[,-1])
	expect_error(y[-1,])
	expect_error(y[,ncol(y) + 1])
	expect_error(y[nrow(y) + 1,])

	z <- y[1:5,1:5,drop=NULL]

	expect_is(z, "sparse_mat")
	expect_equal(x[1:5,1:5], z[])

})

test_that("sparse matrix subsetting (csr)", {

	set.seed(1, kind="default")
	x <- rbinom(200, 1, 0.2)
	x[x != 0] <- seq_len(sum(x != 0))
	dim(x) <- c(20, 10)
	y <- sparse_mat(x, rowMaj=TRUE)

	expect_equal(x, y[])
	expect_equal(x[,1], y[,1])
	expect_equal(x[1,], y[1,])
	expect_equal(x[,10], y[,10])
	expect_equal(x[20,], y[20,])
	expect_equal(x[1:10,1:5], y[1:10,1:5])
	expect_equal(x[10:1,5:1], y[10:1,5:1])
	expect_equal(x[11:20,6:10], y[11:20,6:10])
	expect_equal(x[,c(1,NA,10)], y[,c(1,NA,10)])
	expect_equal(x[c(1,NA,10),], y[c(1,NA,10),])
	expect_equal(x[1,,drop=FALSE], as.matrix(y[1,,drop=NULL]))
	expect_error(y[,-1])
	expect_error(y[-1,])
	expect_error(y[,ncol(y) + 1])
	expect_error(y[nrow(y) + 1,])

	z <- y[1:5,1:5,drop=NULL]

	expect_is(z, "sparse_mat")
	expect_equal(x[1:5,1:5], z[])

	y <- sparse_mat(x, pointers=TRUE, rowMaj=TRUE)

	expect_equal(x, y[])
	expect_equal(x[,1], y[,1])
	expect_equal(x[1,], y[1,])
	expect_equal(x[,10], y[,10])
	expect_equal(x[20,], y[20,])
	expect_equal(x[1:10,1:5], y[1:10,1:5])
	expect_equal(x[10:1,5:1], y[10:1,5:1])
	expect_equal(x[11:20,6:10], y[11:20,6:10])
	expect_equal(x[,c(1,NA,10)], y[,c(1,NA,10)])
	expect_equal(x[c(1,NA,10),], y[c(1,NA,10),])
	expect_error(y[,-1])
	expect_error(y[-1,])
	expect_error(y[,ncol(y) + 1])
	expect_error(y[nrow(y) + 1,])

	z <- y[1:5,1:5,drop=NULL]

	expect_is(z, "sparse_mat")
	expect_equal(x[1:5,1:5], z[])

})

test_that("sparse matrix subsetting w/ interpolation", {

	set.seed(1, kind="default")
	x <- rbinom(200, 1, 0.2)
	x[x != 0] <- seq_len(sum(x != 0))
	dim(x) <- c(20, 10)
	d <- seq_len(nrow(x)) - 1 + round(runif(nrow(x))/4, 2)
	y <- sparse_mat(x, domain=d, tolerance=0.5)

	expect_equal(x, y[])
	expect_equal(x[,1], y[,1])
	expect_equal(x[1,], y[1,])
	expect_equal(x[,10], y[,10])
	expect_equal(x[20,], y[20,])
	expect_equal(x[1:10,1:5], y[1:10,1:5])
	expect_equal(x[10:1,5:1], y[10:1,5:1])
	expect_equal(x[11:20,6:10], y[11:20,6:10])

	d <- seq_len(ncol(x)) - 1 + round(runif(ncol(x))/4, 2)
	y <- sparse_mat(x, domain=d, tolerance=0.5, rowMaj=TRUE)

	expect_equal(x, y[])
	expect_equal(x[,1], y[,1])
	expect_equal(x[1,], y[1,])
	expect_equal(x[,10], y[,10])
	expect_equal(x[20,], y[20,])
	expect_equal(x[1:10,1:5], y[1:10,1:5])
	expect_equal(x[10:1,5:1], y[10:1,5:1])
	expect_equal(x[11:20,6:10], y[11:20,6:10])

	z <- sparse_mat(list(as.double(1:5)), list(1:5), nrow=5, ncol=1)
	domain(z) <- seq(from=2, to=3, by=0.25)
	tolerance(z) <- 0.3

	expect_equal(c(2, 2, 0, 3, 3), as.double(z[]))

})

test_that("sparse matrix combining", {

	set.seed(1, kind="default")
	x <- rbinom(200, 1, 0.2)
	x[x != 0] <- seq_len(sum(x != 0))
	dim(x) <- c(20, 10)
	y <- sparse_mat(x)

	expect_equal(cbind(x, x), cbind(y, y)[])

	y <- sparse_mat(x, rowMaj=TRUE)

	expect_equal(rbind(x, x), rbind(y, y)[])

})

test_that("sparse matrix multiplication", {

	set.seed(1, kind="default")
	x <- rbinom(35, 1, 0.4)
	y <- rbinom(35, 1, 0.4)
	x[x != 0] <- seq_len(sum(x != 0))
	y[y != 0] <- seq_len(sum(y != 0))
	dim(x) <- c(5, 7)
	dim(y) <- c(7, 5)

	options(matter.matmul.bpparam=NULL)
	xx <- sparse_mat(x)
	yy <- sparse_mat(y)

	expect_equal(x %*% y, xx %*% y)
	expect_equal(x %*% y, x %*% yy)
	expect_equal(y %*% x, yy %*% x)
	expect_equal(y %*% x, y %*% xx)
	expect_equal(crossprod(x, x), crossprod(xx, x))
	expect_equal(crossprod(x, x), crossprod(x, xx))
	expect_equal(tcrossprod(x, x), tcrossprod(xx, x))
	expect_equal(tcrossprod(x, x), tcrossprod(x, xx))

	options(matter.matmul.bpparam=SerialParam())

	expect_equal(x %*% y, xx %*% y)
	expect_equal(x %*% y, x %*% yy)
	expect_equal(y %*% x, yy %*% x)
	expect_equal(y %*% x, y %*% xx)
	expect_equal(crossprod(x, x), crossprod(xx, x))
	expect_equal(crossprod(x, x), crossprod(x, xx))
	expect_equal(tcrossprod(x, x), tcrossprod(xx, x))
	expect_equal(tcrossprod(x, x), tcrossprod(x, xx))

	options(matter.matmul.bpparam=NULL)
	xx <- matter_mat(x, rowMaj=TRUE)
	yy <- matter_mat(y, rowMaj=TRUE)

	expect_equal(x %*% y, xx %*% y)
	expect_equal(x %*% y, x %*% yy)
	expect_equal(y %*% x, yy %*% x)
	expect_equal(y %*% x, y %*% xx)
	expect_equal(crossprod(x, x), crossprod(xx, x))
	expect_equal(crossprod(x, x), crossprod(x, xx))
	expect_equal(tcrossprod(x, x), tcrossprod(xx, x))
	expect_equal(tcrossprod(x, x), tcrossprod(x, xx))

	options(matter.matmul.bpparam=SerialParam())

	expect_equal(x %*% y, xx %*% y)
	expect_equal(x %*% y, x %*% yy)
	expect_equal(y %*% x, yy %*% x)
	expect_equal(y %*% x, y %*% xx)
	expect_equal(crossprod(x, x), crossprod(xx, x))
	expect_equal(crossprod(x, x), crossprod(x, xx))
	expect_equal(tcrossprod(x, x), tcrossprod(xx, x))
	expect_equal(tcrossprod(x, x), tcrossprod(x, xx))

})

test_that("sparse fetch/flash", {

	register(SerialParam())

	set.seed(1, kind="default")
	x0 <- rbinom(100, 1, 0.2)
	x0[x0 != 0] <- seq_len(sum(x0 != 0))
	y0 <- sparse_vec(x0)

	y0a <- fetch(y0)
	y0b <- flash(y0)

	expect_equal(y0a[], x0)
	expect_equal(y0b[], x0)
	expect_true(is.shared(atomindex(y0a)))
	expect_true(is.shared(atomdata(y0a)))
	expect_true(is.matter(atomindex(y0b)))
	expect_true(is.matter(atomdata(y0b)))

	y1 <- y0
	atomindex(y1) <- as.matter(atomindex(y1))
	atomdata(y1) <- as.matter(atomdata(y1))
	y1a <- fetch(y1)
	y1b <- flash(y1)
	
	expect_equal(y1a[], x0)
	expect_equal(y1b[], x0)	
	expect_true(is.shared(atomindex(y1a)))
	expect_true(is.shared(atomdata(y1a)))	
	expect_true(is.matter(atomindex(y1b)))
	expect_true(is.matter(atomdata(y1b)))

	set.seed(1, kind="default")
	x1 <- rbinom(200, 1, 0.2)
	x1[x1 != 0] <- seq_len(sum(x1 != 0))
	dim(x1) <- c(20, 10)
	y2 <- sparse_mat(x1)

	y2a <- fetch(y2)
	y2b <- flash(y2)

	expect_equal(y2a[], x1)
	expect_equal(y2b[], x1)
	expect_true(is.shared(atomindex(y2a)))
	expect_true(is.shared(atomdata(y2a)))
	expect_true(is.matter(atomindex(y2b)))
	expect_true(is.matter(atomdata(y2b)))

	y3 <- y2
	atomindex(y3) <- as.matter(atomindex(y3))
	atomdata(y3) <- as.matter(atomdata(y3))
	y3a <- fetch(y3)
	y3b <- flash(y3)
	
	expect_equal(y3a[], x1)
	expect_equal(y3b[], x1)	
	expect_true(is.shared(atomindex(y3a)))
	expect_true(is.shared(atomdata(y3a)))
	expect_true(is.matter(atomindex(y3b)))
	expect_true(is.matter(atomdata(y3b)))

})
