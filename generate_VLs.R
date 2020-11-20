# Some HIV-specific functionality: S3 classes for viral loads
is.suppressed <- function(x) UseMethod("is.suppressed")
is.suppressed.MissingVL <- function(vl) FALSE
is.suppressed.NumericVL <- function(vl) vl$value <= 1000
is.suppressed.CategoricalVL <- function(vl) vl$value == 1306 | vl$value == 1302

MissingVL <- function(x = NA) new_MissingVL()
new_MissingVL <- function(x = NA) structure(NA_real_, class = c("VL", "MissingVL"))
print.MissingVL <- function(x, ...) print(unclass(x))

NumericVL <- function(x = numeric()) {
  v <- as.double(x)
  if (is.na(v) || v < 20) {
    stop("NumericVL values must be positive numbers greater than or equal to 20",
         call. = FALSE)
  }
  
  new_NumericVL(v)
}
new_NumericVL <- function(x = numeric()) {
  stopifnot(is.double(x))
  structure(list(value = x), class = c("VL", "NumericVL"))
}
print.NumericVL <- function(x, ...) print(paste0(x$value, " #/mL"))

CategoricalVL <- function(x = integer()) {
  v <- as.integer(x)
  if (length(v) == 0 || is.na(v) || !(v %in% c(1301, 1302, 1304, 1306))) {
    stop("CategoricalVL values must be one of 1301, 1302, 1304, or 1306",
         call. = FALSE)
  }
  
  new_CategoricalVL(as.integer(x))
}
new_CategoricalVL <- function(x = integer()) {
  stopifnot(is.integer(x))
  structure(list(value = x), class = c("VL", "CategoricalVL"))
}
print.CategoricalVL <- function(x, ...)
  print(case_when(
    x$value == 1301 ~ "Detected",
    x$value == 1302 ~ "Not Detected",
    x$value == 1304 ~ "Poor Sample",
    x$value == 1306 ~ "Beyond detectable limit"
  ))
