# Plot a fitted PINN

Plot a fitted PINN

## Usage

``` r
# S3 method for class 'pinn_fit'
plot(x, type = c("loss", "solution", "parameters"), output = NULL, ...)
```

## Arguments

- x:

  A `pinn_fit`.

- type:

  `"loss"` for the training history, `"solution"` for the fitted outputs
  (1D and 2D domains), or `"parameters"` for the path of estimated
  parameters during training.

- output:

  For 2D solutions, which output to draw.

- ...:

  Passed to the underlying base graphics function.

## Value

`x`, invisibly.
