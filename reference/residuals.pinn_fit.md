# Equation residuals of a fitted PINN

Evaluates the equation residual at new points. Values close to zero mean
the network satisfies the equation there; large values show where the
solution is unreliable.

## Usage

``` r
# S3 method for class 'pinn_fit'
residuals(object, newdata = NULL, ...)
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

A data frame with the domain variables followed by one residual column
per equation.
