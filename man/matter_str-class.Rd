\name{matter_str-class}
\docType{class}

\alias{class:matter_str}
\alias{matter_str}
\alias{matter_str-class}

\alias{lengths,matter_str-method}

\alias{[,matter_str-method}
\alias{[,matter_str,ANY,ANY,ANY-method}
\alias{[,matter_str,ANY,missing,ANY-method}
\alias{[,matter_str,missing,missing,ANY-method}
\alias{[<-,matter_str-method}
\alias{[<-,matter_str,ANY,ANY,ANY-method}
\alias{[<-,matter_str,ANY,missing,ANY-method}
\alias{[<-,matter_str,missing,missing,ANY-method}

\alias{[[,matter_str,ANY,missing-method}
\alias{[[<-,matter_str,ANY,missing-method}

\title{Strings Stored on Disk}

\description{
    The \code{matter_str} class implements on-disk strings.
}

\usage{
## Instance creation
matter_str(data, datamode = "raw", paths = NULL,
            filemode = ifelse(all(file.exists(paths)), "rb", "rb+"),
            offset = c(0, cumsum(sizeof(datamode) * extent)[-length(extent)]),
            extent = nchar, nchar = 0, names = NULL, \dots)

## Additional methods documented below
}

\arguments{
        \item{data}{An optional character vector which will be initially written to the data on disk if provided.}

        \item{datamode}{A 'character' vector giving the storage mode of the data on disk. Allowable values are the C types ('char', 'uchar', short', 'ushort', 'int', 'uint', 'long', 'ulong', 'float') and their R equivalents ('raw', 'logical', 'integer', 'numeric').}

        \item{paths}{A 'character' vector of the paths to the files where the data are stored. If 'NULL', then a temporary file is created using \code{\link[base]{tempfile}}.}

        \item{filemode}{The read/write mode of the files where the data are stored. This should be 'rb' for read-only access, or 'rb+' for read/write access.}

        \item{offset}{A vector giving the offsets in number of bytes from the beginning of each file in 'paths', specifying the start of the data to be accessed for each file.}

        \item{extent}{A vector giving the length of the data for each file in 'paths', specifying the number of elements of size 'datamode' to be accessed from each file.}

        \item{nchar}{A vector giving the length of each element of the character vector.}

        \item{names}{The names of the data elements.}

        \item{\dots}{Additional arguments to be passed to constructor.}
}

\section{Slots}{
    \describe{
        \item{\code{data}:}{This slot stores the information about locations of the data on disk and within the files.}

        \item{\code{datamode}:}{The storage mode of the \emph{accessed} data when read into R. This is a 'character' vector of length one with value 'integer' or 'numeric'.}

        \item{\code{paths}:}{A 'character' vector of the paths to the files where the data are stored.}

        \item{\code{filemode}:}{The read/write mode of the files where the data are stored. This should be 'rb' for read-only access, or 'rb+' for read/write access.}

        \item{\code{chunksize}:}{The maximum number of elements which should be loaded into memory at once. Used by methods implementing summary statistics and linear algebra. Ignored when explicitly subsetting the dataset.}

        \item{\code{length}:}{The length of the data.}

        \item{\code{dim}:}{Either 'NULL' for vectors, or an integer vector of length one of more giving the maximal indices in each dimension for matrices and arrays.}

        \item{\code{names}:}{The names of the data elements for vectors.}

        \item{\code{dimnames}:}{Either 'NULL' or the names for the dimensions. If not 'NULL', then this should be a list of character vectors of the length given by 'dim' for each dimension. This is always 'NULL' for vectors.}

        \item{\code{ops}:}{Delayed operations to be applied on atoms.}
    }
}

\section{Extends}{
   \code{\linkS4class{matter}}
}

\section{Creating Objects}{
    \code{matter_str} instances can be created through \code{matter_str()} or \code{matter()}.
}

\section{Methods}{
    Standard generic methods:
    \describe{
        \item{\code{x[[i]], x[[i]] <- value}:}{Get or set the string elements of the vector.}

        \item{\code{x[i,j], x[i,j] <- value}:}{Get or set the string elements of the vector.}

        \item{\code{lengths(x)}:}{Get the number of characters (in bytes) of all string elements in the vector.}
    }
}

\value{
    An object of class \code{\linkS4class{matter_str}}.
}

\author{Kylie A. Bemis}

\seealso{
    \code{\linkS4class{matter}}
}

\examples{
x <- matter_str(c("hello", "world!"))
x[]
}

\keyword{classes}
\keyword{array}
\keyword{IO}