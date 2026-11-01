# Sample points in a domain

Draws training points uniformly at random or with Latin hypercube
sampling. Variables listed in `fixed` are held at the given values,
which is how boundary and initial points are generated.

## Usage

``` r
pinn_sample(n, domain, method = c("lhs", "uniform"), fixed = list())
```

## Arguments

- n:

  Number of points.

- domain:

  A
  [`pinn_domain()`](https://obasanmii.github.io/pinnr/reference/pinn_domain.md).

- method:

  `"lhs"` (Latin hypercube, the default) or `"uniform"`.

- fixed:

  Named list of numeric values. When a variable has several values, the
  points are split evenly between them. With several fixed variables,
  every combination of their values is used, so
  `list(x = c(0, 1), y = c(0, 1))` gives the four corners. Each value
  (or combination) gets at least one point, so the result can have more
  than `n` rows when `n` is smaller than the number of combinations.

## Value

A data frame with one column per domain variable.

## Examples

``` r
dom <- pinn_domain(x = c(0, 1), t = c(0, 2))
head(pinn_sample(5, dom))
#>           x          t
#> 1 0.7723993 1.97610760
#> 2 0.3928102 0.77896715
#> 3 0.1289966 1.21089190
#> 4 0.9242108 0.08215696
#> 5 0.4770447 1.18733292
pinn_sample(4, dom, fixed = list(x = c(0, 1)))
#>   x         t
#> 1 0 0.4947259
#> 2 0 0.5910430
#> 3 1 1.0718271
#> 4 1 1.7888452
```
