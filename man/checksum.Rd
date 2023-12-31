\name{checksum}
\docType{methods}

\alias{checksum}
\alias{checksum,character-method}
\alias{checksum,atoms-method}
\alias{checksum,matter_-method}

\title{Calculate Checksums and Cryptographic Hashes}

\description{
    This is a generic function for applying cryptographic hash functions and calculating checksums for externally-stored R objects.
}

\usage{
checksum(x, \dots)

\S4method{checksum}{character}(x, algo = "sha1", \dots)

\S4method{checksum}{matter_}(x, algo = "sha1", \dots)
}

\arguments{
    \item{x}{A file path or an object to be hashed.}
    
    \item{algo}{The hash function to use.}

    \item{\dots}{Additional arguments to be passed to the hash function.}
}

\details{
	The method for \code{\linkS4class{matter}} objects calculates checksums of each of the files in the object's \code{paths}.
}

\value{
	A character vector giving the hash or hashes of the object.
}

\author{Kylie A. Bemis}

\seealso{
    \code{\link{digest}}
}

\examples{
x <- matter(1:10)
y <- matter(1:10)

checksum(x)
checksum(y) # should be the same
}

\keyword{utilities}
