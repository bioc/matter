\name{drle-class}
\docType{class}

\alias{class:drle}
\alias{drle}
\alias{drle-class}

\alias{class:drle_fct}
\alias{drle_fct}
\alias{drle_fct-class}

\alias{[,drle,ANY,ANY,ANY-method}
\alias{[,drle_fct,ANY,ANY,ANY-method}
\alias{c,drle-method}
\alias{length,drle-method}

\alias{combine,drle,drle-method}
\alias{combine,drle,numeric-method}
\alias{combine,numeric,drle-method}
\alias{combine,drle_fct,drle_fct-method}

\alias{levels,drle_fct-method}
\alias{levels<-,drle_fct-method}
\alias{droplevels,drle_fct-method}

\alias{type,drle-method}

\alias{as.data.frame,drle-method}
\alias{as.vector,drle-method}
\alias{as.integer,drle-method}
\alias{as.numeric,drle-method}
\alias{as.list,drle-method}
\alias{as.factor,drle_fct-method}

\alias{is.drle}

\title{Delta Run Length Encoding}

\description{
    The \code{drle} class stores delta-run-length-encoded vectors. These differ from other run-length-encoded vectors provided by other packages in that they allow for runs of values that each differ by a common difference (delta).
}

\usage{
## Instance creation
drle(x, type = "drle", cr_threshold = 0)

is.drle(x)
## Additional methods documented below
}

\arguments{
    \item{x}{An integer or numeric vector to convert to delta run length encoding for \code{drle()}; an object to test if it is of class \code{drle} for \code{is.drle()}.}

    \item{type}{The type of compression to use. Must be "drle", "rle", or "seq". The default ("drle") allows arbitrary deltas. Using type "rle" means that runs must consist of a single value (i.e., deltas must be 0). Using type "seq" means that deltas must be 1, -1, or 0.}

    \item{cr_threshold}{The compression ratio threshold to use when converting a vector to delta run length encoding. The default (0) always converts the object to \code{drle}. Values of \code{cr_threshold} < 1 correspond to compressing even when the output will be larger than the input (by a certain ratio). For values > 1, compression will only take place when the output is (approximately) at least \code{cr_threshold} times smaller.}
}

\section{Slots}{
    \describe{
        \item{\code{values}:}{The values that begin each run.}

        \item{\code{lengths}:}{The length of each run.}

        \item{\code{deltas}:}{The difference between the values of each run.}
    }
}

\section{Creating Objects}{
    \code{drle} instances can be created through \code{drle()}.
}

\section{Methods}{
    Standard generic methods:
    \describe{
        \item{\code{x[i]}:}{Get the elements of the uncompressed vector.}

        \item{\code{length(x)}:}{Get the length of the uncompressed vector.}

        \item{\code{c(x, ...)}:}{Combine vectors.}
    }
}

\value{
    An object of class \code{\linkS4class{drle}}.
}

\author{Kylie A. Bemis}

\seealso{
    \code{\link{rle}}
}

\examples{
## Create a drle vector
x <- c(1,1,1,1,1,6,7,8,9,10,21,32,33,34,15)
y <- drle(x)

# Check that their elements are equal
x == y[]
}

\keyword{classes}
