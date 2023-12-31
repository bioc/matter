require(testthat)
require(matter)

context("matter-string")

test_that("matter string", {

	x <- c("neon", "genesis", "evangelion")
	y <- matter_str(x)

	expect_equal(x, y[])
	expect_equal(x, as.character(y))
	expect_equal(x[1], y[1])
	expect_equal(x[1:3], y[1:3])
	expect_equal(x[3:1], y[3:1])
	expect_equal("eva", y[3,1:3])
	expect_equal(c("gen", "eva"), y[2:3,1:3])
	expect_equal(c("eva", "gen"), y[3:2,1:3])
	expect_equal(c("ave", "neg"), y[3:2,3:1])

	z <- y[1:2,drop=NULL]

	expect_is(z, "matter_str")
	expect_equal(x[1:2], z[])

	expect_equal(c(x, x), c(y, y)[])

})
