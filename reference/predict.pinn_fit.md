# Predict from a fitted PINN

Evaluates the trained network at new points.

## Usage

``` r
# S3 method for class 'pinn_fit'
predict(object, newdata = NULL, ...)
```

## Arguments

- object:

  A `pinn_fit`.

- newdata:

  Data frame with one column per domain variable. When omitted, the
  `times` given to
  [`pinn_ode()`](https://obasanmii.github.io/pinnr/reference/pinn_ode.md)
  are used for ODE problems, and otherwise a regular grid (201 points in
  1D, 101 x 101 in 2D).

- ...:

  Unused.

## Value

A data frame with the domain variables followed by one column per
output.

## Examples

``` r
decay <- function(t, y, parms) list(-parms["k"] * y)
prob <- pinn_ode(decay, y0 = c(y = 1), times = c(0, 5), parms = c(k = 0.5))
fit <- pinn_fit(prob, hidden = c(16, 16), epochs = 1000, seed = 1)
predict(fit, data.frame(time = c(0, 1, 2)))
#>   time         y
#> 1    0 1.0000000
#> 2    1 0.6344568
#> 3    2 0.3608426
```
