\name{coscore}

\alias{coscore}

\title{Colocalization Coefficients}

\description{
    Compute Manders overlap coefficient (MOC), and Manders colocalization coefficients (M1 and M2), and Dice similarity coefficient.
}

\usage{
coscore(x, y, threshold = NA)
}

\arguments{
	\item{x, y}{Images to be compared. These can be numeric or logical. If numeric, then the "overlap" is defined where both images are nonzero.}

    \item{threshold}{The intensity threshold to use when comparing the images. If \code{NA}, this will be determined automatically from the technique described in Costes et al. (2004). Alternatively, this can be a function such as \code{median} that can be applied to return a suitable threshold.}
}

\details{
    The Dice coefficient and Manders overlap coefficient are symmetric between images, while M1 and M2 measure the overlap relative to \code{x} and \code{y} respectively.
}

\value{
    A numeric vector with elements named "MOC", "M1", "M2", and "Dice", and an attribute named "threshold" giving the numeric thresholds (if applicable) for converting each image to a logical mask.
}

\author{Kylie A. Bemis}

\references{
    K. W. Dunn, M. M. Kamocka, and J. H. McDonald. ``A practical guide to evaluating colocalization in biological microscop.'' American Journal of Physiology: Cell Physiology, vol. 300, no. 4, pp. C732-C742, 2011.

    S. V. Costes, D. Daelemans, E. H. Cho, Z. Dobbin, G. Pavlakis, and S. Lockett. ``Automatic and Quantitative Measurement of Protein-Protein Colocalization in Live Cells.'' Biophysical Journal, vol. 86, no. 6, pp. 3993-4003, 2004.

    K. H. Zou, S. K. Warfield, A. Bharatha, C. M. C. Tempany, M. R. Kaus, S. J. Haker, W. M. Wells, III, F. A. Jolesz, and R. Kikinis. ``Statistical Validation of Image Segmentation Quality Based on a Spatial Overlap Index.'' Academic Radiology, vol. 11, issue 2, pp. 178-189, 2004.
}

\examples{
set.seed(1)
y <- x <- matrix(0, nrow=32, ncol=32)
x[5:16,5:16] <- 1
x[17:28,17:28] <- 1
x <- x + runif(length(x))
y[4:15,4:15] <- 1
y[18:29,18:29] <- 1
y <- y + runif(length(y))
xl <- x > median(x)
yl <- y > median(y)

coscore(x, x)
coscore(x, y)
coscore(x, y, threshold=median)
coscore(xl, yl)
}

\keyword{utilities}
