\name{knnsearch}

\alias{kdtree}
\alias{kdsearch}
\alias{knnsearch}

\title{K-Dimensional Nearest Neighbor Search}

\description{
    Search a matrix of K-dimensional data points and return the indices of the nearest neighbors or of all data points that are within a specified tolerance in each dimension.
}

\usage{
# Nearest neighbor search
knnsearch(x, data, k = 1L, metric = "euclidean", p = 2)

# Range search
kdsearch(x, data, tol = 0, tol.ref = "abs")

# K-D tree
kdtree(data)
}

\arguments{
	\item{x}{A numeric matrix of coordinates to be matched. Each column should represent a dimension. Each row should be a query point.}

	\item{data}{Either a \code{kdtree} object returned by \code{kdtree()}, or a numeric matrix of coordinates to search, where each column is a different dimension. If this is missing, then the query \code{x} will be used as the data.}

	\item{k}{The number of nearest neighbors to find for each point (row) in \code{x}.}

	\item{metric}{Distance metric to use when finding the nearest neighbors. Supported metrics include "euclidean", "maximum", "manhattan", and "minkowski".}

	\item{p}{The power for the Minkowski distance.}

	\item{tol}{The tolerance for finding neighboring points in each dimension. May be a vector with the same length as the number of dimensions. Must be positive.}

	\item{tol.ref}{One of 'abs', 'x', or 'y'. If 'abs', then comparison is done by taking the absolute difference. If either 'x' or 'y', then relative differences are used, and this specifies which to use as the reference (target) value.}
}

\details{
	\code{knnsearch()} performs k-nearest neighbor searches. \code{kdsearch()} performs range searches for points within a given tolerance of the query points.

    The algorithms are implemented in C and work by building a kd-tree to perform the search. If multiple calls to \code{kdsearch()} or \code{knnsearch()} are expected on the same data, it can be much faster to build the tree once with \code{kdtree()}.

    A kd-tree is essentially a multidimensional generalization of a binary search tree. Building the search tree is O(n * log n) and searching for a single data point is O(log n).

    For \code{knnsearch()}, ties are broken based on the original ordering of the rows in \code{data}.
}

\value{
	For \code{knnsearch()}, a matrix with rows equal to the number of rows of \code{x} and columns equal to \code{k} giving the indices of the k-nearest neighbors.
	
	For \code{kdsearch()}, a list with length equal to the number of rows of \code{x}, where each list element is a vector of indexes of the matches in \code{data}.
}

\author{Kylie A. Bemis}

\seealso{
	\code{\link{bsearch}},
	\code{\link{approx2}},
}

\examples{
d <- expand.grid(x=1:10, y=1:10)
x <- rbind(c(1.11, 2.22), c(3.33, 4.44))

knnsearch(x, d, k=3)
}

\keyword{tree}
\keyword{spatial}
\keyword{utilities}
