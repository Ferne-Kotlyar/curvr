#' Calculate total curvature from smoothing or interpolating splines.
#'
#'
#' @param landmark_matrix is a \code{matrix} object with \code{[,1]}
#' containing the x landmark coordinates and \code{[,2]} containing
#' the y landmark coordinates.
#'
#' @param x_range the lower and upper x-value bounds to
#' calculate curvature. Concatenate the lower and upper bounds using
#' \code{c()}, E.g. for lower = 1 and upper = 10, type \code{c(1,10)}.
#'
#' @param type either 'ip' for an interpolating spline or 'smooth' for a
#' smoothing spline. Uses \code{stats::spline()} or \code{stats::smooth.spline()}, respectively,
#' for curve fitting and estimating the derivatives. Default is \code{type = 'smooth'}.
#' See: ?spline and ?smooth.spline for details.
#'
#' @return a `list` with two named elements. `$Ktot` is the total curvature in radians. `$Ki` is a numeric vector of local curvature values.
#'
#' @examples
#'
#' # a landmark matrix describing a segment of the unit circle#'
#' x <- seq(0, 1, by = 0.01)
#' y <- sqrt(1-x^2)
#' mdat <- matrix(c(x, y), nrow = 101, ncol = 2)
#'
#' # total curvature between x=0 and x=sqrt(2)/2 should be approximately pi/4
#' abs(curvature_spline(mdat, c(0, sqrt(2)/2), type='smooth')$Ktot)
#'
#' @importFrom dplyr %>%
#' @importFrom stats smooth.spline predict splinefun spline integrate
#' @importFrom assertthat assert_that
#'
#' @export

curvature_spline <- function(landmark_matrix, x_range, type = 'smooth') {

  # check that landmark_matrix has two columns
  assert_that(is.matrix(landmark_matrix), ncol(landmark_matrix) == 2,
              msg = "landmark_matrix must be a two-column matrix.")

  # check that x_range has upper and lower bounds
  assert_that(is.numeric(x_range), length(x_range) == 2,
              msg = "x_range must be a numeric vector of length 2.")

  # check for valid spline type
  assert_that(type %in% c("smooth", "ip"),
              msg = "type must be either 'smooth' or 'ip'.")

  # extract/separate x and y coords
  x_coords <- landmark_matrix[, 1]
  y_coords <- landmark_matrix[, 2]


  if (type == 'smooth'){
    # fit a spline to landmark coordinates
    s0 <- smooth.spline(landmark_matrix)

    # first deriv values
    s1 <- predict(s0, deriv = 1)

    # fit spline func to first deriv values
    s1func <- splinefun(x = s1$x, y = s1$y)

    # second deriv func (1st deriv of s1)
    s2func <- splinefun(x = s1$x, y = s1func(s1$x, deriv = 1))

  } else if (type == 'ip'){

    # compute coordinates from a cubic spline fit
    s0 <- spline(landmark_matrix)

    # create a spline function from coordinates
    s0func <- splinefun(s0$x, s0$y)

    # estimate y coords of first derivative
    s1 <- s0func(s0$x, deriv = 1)

    # create a function for first derivative
    s1func <- splinefun(s0$x, s1)

    # create a function for second derivative
    s2func <- splinefun(x = s0$x, y = s1func(s0$x, deriv = 1))

  }

  # define K * ds
  k_fun <- function(x) {
    f1 <- s1func
    f2 <- s2func
    ((f2(x)) / ((1 + (f1(x)^2))^1.5)) * (sqrt(1 + (f1(x))^2))
  }

  # compute integral of K*ds
  Ktot <- integrate(k_fun, lower = x_range[1], upper = x_range[2])$value

  # compute point-wise K from second deriv function
  Ki <- s2func(landmark_matrix[,1])

  curvature <- list(Ktot = Ktot, Ki = Ki)
  return(curvature)

}
