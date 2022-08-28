require(testthat)
require(matter)

context("drle-class")

test_that("drle indexing - integer", {

	x <- c(rep(1L, 10), 10:1, 1:10)
	y <- drle(x)

	expect_equal(x, y[])
	expect_equal(x[1], y[1])
	expect_equal(x[1:30], y[1:30])
	expect_equal(x[30:1], y[30:1])

})

test_that("drle indexing - double", {

	x <- c(1,1,1,1,1,6,7,8,9,10,21,32,33,34,15)
	y <- drle(x)

	expect_equal(x, y[])
	expect_equal(x[1], y[1])
	expect_equal(x[1:15], y[1:15])
	expect_equal(x[15:1], y[15:1])

})

test_that("drle subsetting", {

	x <- c(1,1,1,1,1,6,7,8,9,10,21,32,33,34,15)
	y <- drle(x)

	expect_equal(y, y[1:15,drop=NA])
	expect_equal(x[1:15], y[1:15,drop=NA][])
	expect_equal(x[15:1], y[15:1,drop=NA][])
	expect_equal(x[c(1,3,5,7)], y[c(1,3,5,7),drop=NA][])
	expect_equal(x[c(3:7,11:14)], y[c(3:7,11:14),drop=NA][])

	x <- c(rep(1L, 10), 10:1, 1:10)
	y <- drle(x)

	expect_equal(y, y[1:30,drop=NA])
	expect_equal(x[1:30], y[1:30,drop=NA][])
	expect_equal(x[30:1], y[30:1,drop=NA][])
	expect_equal(x[c(7,9,11,13)], y[c(7,9,11,13),drop=NA][])
	expect_equal(x[c(7:13,17:23)], y[c(7:13,17:23),drop=NA][])

})

test_that("drle combining", {

	x1 <- c(1,1,1,1,1,6,7,8,9,10,21,32,33,34,15)
	x2 <- c(rep(1L, 10), 10:1, 1:10)
	y1 <- drle(x1)
	y2 <- drle(x2)

	x3 <- c(x1, x2)
	y3 <- c(y1, y2)

	expect_equal(x3, y3[])
	expect_equal(x3[1], y3[1])
	expect_equal(x3[1:45], y3[1:45])
	expect_equal(x3[45:1], y3[45:1])

})