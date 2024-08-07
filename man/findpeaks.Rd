\name{findpeaks}

\alias{findpeaks}
\alias{locmax}
\alias{locmin}

\title{Peak Detection}

\description{
    Find peaks in a signal based on its local maxima, as determined by a sliding window.
}

\usage{
# Find peaks
findpeaks(x, width = 5L, prominence = NULL,
    snr = NULL, noise = "quant", bounds = TRUE,
    relheight = 0.005, \dots)

# Local maxima
locmax(x, width = 5L)

# Local minima
locmin(x, width = 5L)
}

\arguments{
	\item{x}{A numeric vector.}

    \item{width}{The number of signal elements to consider when determining if the center of the sliding window is a local extremum.}

    \item{prominence}{The minimum peak prominence used for filtering the peaks. The prominence of a peak is the height that the peak rises above the higher of its bases (i.e., its lowest contour line). A peak's bases are found as the local minima between the peak and the next higher peaks on either side.}

    \item{snr}{The minimum signal-to-noise ratio used for filtering the peaks.}

    \item{noise}{The method used to estimate the noise. See \emph{Details}.}

    \item{bounds}{Whether the boundaries of each peak should be calculated and returned. A peak's boundaries are found as the nearest local minima on either side.}

    \item{relheight}{The minimum relative height (proportion of the maximum peak value) used for filtering the peaks.}

    \item{\dots}{Arguments passed to the noise estimation function.}
}

\details{
    For \code{locmax()} and \code{locmin()}, a local extremum is defined as an element greater (or less) than all of the elements within \code{width / 2} elements to the left of it, and greater (or less) than or equal to all of the elements within \code{width / 2} elements to the right of it. That is, ties are resolved such that only the leftmost sample is considered the local extremum.

    For \code{findpeaks()}, the peaks are simply the local maxima of the signal. The peak boundaries are found by descending a local maximum until a local minimum is found on either side, using the same criteria as above. The peaks are optionally filtered based on their prominences.

    Optionally, the signal-to-noise ratio (SNR) can be estimated and used for filtering the peaks. These use the functions \code{\link{estnoise_quant}}, \code{\link{estnoise_diff}}, \code{\link{estnoise_filt}}, etc., to estimate the noise in the signal.
}

\value{
    For \code{locmax()} and \code{locmin()}, an logical vector indicating whether each element is a local extremum.

    For \code{findpeaks()}, an integer vector giving the indices of the peaks, with attributes 'left_bounds' and 'right_bounds' giving the left and right boundaries of the peak as determined using the rule above.
}

\author{Kylie A. Bemis}

\seealso{
    \code{\link{findpeaks_cwt}},
    \code{\link{findpeaks_knn}},
    \code{\link{estnoise_quant}},
    \code{\link{estnoise_sd}},
    \code{\link{estnoise_mad}},
    \code{\link{estnoise_diff}},
    \code{\link{estnoise_filt}},
    \code{\link{peakwidths}},
    \code{\link{peakareas}},
    \code{\link{peakheights}},
    \code{\link{binpeaks}},
    \code{\link{mergepeaks}}
}

\examples{
# simple signal
x <- c(0, 1, 1, 2, 3, 2, 1, 4, 5, 1, 1, 0)
locmax(x)
findpeaks(x)

# simulated spectrum
set.seed(1)
x <- simspec(size=5000)

# find peaks with snr >= 3
p <- findpeaks(x, snr=3, noise="quant")
plot(x, type="l")
points(p, x[p], col="red")

# find peaks with derivative-based noise
p <- findpeaks(x, snr=3, noise="diff")
plot(x, type="l")
points(p, x[p], col="red")
}

\keyword{ts}
