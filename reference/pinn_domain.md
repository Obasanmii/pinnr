# Define a rectangular domain

Each argument names an input variable of the problem and gives its range
as `c(lower, upper)`. The order of the arguments is the order in which
the variables enter the network.

## Usage

``` r
pinn_domain(...)
```

## Arguments

- ...:

  Named numeric vectors of length 2, for example
  `x = c(0, 1), t = c(0, 10)`.

## Value

An object of class `pinn_domain`.

## Examples

``` r
pinn_domain(x = c(-1, 1), t = c(0, 1))
#> <pinn_domain>
#>   x in [-1, 1]
#>   t in [0, 1]
```
