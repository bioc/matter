\name{chunked-class}
\docType{class}

\alias{class:chunked}
\alias{chunked}
\alias{chunked-class}

\alias{class:chunked_vec}
\alias{chunked_vec}
\alias{chunked_vec-class}

\alias{class:chunked_arr}
\alias{chunked_arr}
\alias{chunked_arr-class}

\alias{class:chunked_mat}
\alias{chunked_mat}
\alias{chunked_mat-class}

\alias{class:chunked_list}
\alias{chunked_list}
\alias{chunked_list-class}

\alias{length,chunked-method}
\alias{lengths,chunked-method}
\alias{[,chunked,ANY,ANY,ANY-method}
\alias{[[,chunked_vec-method}
\alias{[[,chunked_mat-method}
\alias{[[,chunked_list-method}

\alias{describe_for_display,chunked-method}
\alias{preview_for_display,chunked-method}
\alias{preview_for_display,chunked_list-method}

\alias{as.list,chunked-method}

\alias{chunkify}

\title{Chunked Vectors, Arrays, and Lists}

\description{
    The \code{chunked} class implements chunked wrappers for vectors, arrays, and lists for parallel iteration.
}

\usage{
## Instance creation
chunked_vec(x, nchunks = NA, chunksize = NA,
    verbose = FALSE, permute = FALSE, depends = NULL, drop = FALSE)

chunked_mat(x, margin, nchunks = NA, chunksize = NA,
    verbose = FALSE, permute = FALSE, depends = NULL, drop = FALSE)

chunked_list(\dots, nchunks = NA, chunksize = NA,
    verbose = FALSE, permute = FALSE, depends = NULL, drop = FALSE)

## Additional methods documented below
}

\arguments{
    \item{x, \dots}{The data to be chunked. If multiple objects are passed via \dots, then they are all recycled to the same length.}

    \item{nchunks}{The number of chunks to use. If \code{NA} (the default), this is taken from \code{getOption("matter.default.nchunks")}. For IO-bound operations, using fewer chunks will often be faster, but use more memory. If both \code{nchunks} and \code{chunksize} are specified, then \code{nchunks} takes priority.}

    \item{chunksize}{The approximate chunk size in bytes. If \code{NA} (the default), this is taken from \code{getOption("matter.default.chunksize")}. For IO-bound operations, using larger chunks will often be faster, but use more memory. If both \code{nchunks} and \code{chunksize} are specified, then \code{nchunks} takes priority.}

    \item{verbose}{Should messages be printed whenever a chunk is extracted?}

    \item{permute}{Should the order of items be randomized? Alternatively, an integer vector or a list of integer vectors can be specified. If an integer vector is provided, then \code{x} is chunked in the exact order of the provided indices. If a list of indices is provided, then these are taken as strata (i.e., subpopulations). Each stratum will be chunked separately and then merged (without randomization), so that each chunk will contain examples from every stratum.}

    \item{depends}{A list with length equal to the extent of \code{X}. Each element of \code{depends} should give a vector of indices which correspond to other elements of \code{X} on which each computation depends. These elements are passed to \code{FUN}. For time  efficiency, no attempt is made to verify these indices are valid.}

    \item{margin}{Which array margin should be chunked.}

    \item{drop}{The value passed to \code{drop} when subsetting the chunks.}
}

\section{Slots}{
    \describe{
        \item{\code{data}:}{The data.}

        \item{\code{index}:}{The chunk indices.}

        \item{\code{verbose}:}{Print messages on chunk extraction?}

        \item{\code{drop}:}{The value passed to \code{drop} when subsetting the chunks.}

        \item{\code{margin}:}{The array margin for the chunks.}
    }
}

\section{Creating Objects}{
    \code{chunked_vec}, \code{chunked_mat} and \code{chunked_list} instances can be created through \code{chunked_vec()}, \code{chunked_mat()}, and \code{chunked_list()}, respectively.
}

\section{Methods}{
    Standard generic methods:
    \describe{
        \item{\code{length(x):}}{Get number of chunks.}

        \item{\code{lengths(x):}}{Get chunk sizes for each chunk.}

        \item{\code{x[i, ...]}:}{Get chunks.}

        \item{\code{x[[i]]}:}{Get a single chunk.}
    }
}

\value{
    An object derived from class \code{\linkS4class{chunked}}.
}

\author{Kylie A. Bemis}

\seealso{
    \code{\link{chunkApply}}
}

\examples{
x <- matrix(runif(200), nrow=10, ncol=20)

y <- chunked_mat(x, margin=2, nchunks=5)
print(y)
}

\keyword{classes}
\keyword{manip}
