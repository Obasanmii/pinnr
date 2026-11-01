# Save and load fitted PINNs

Torch modules cannot be stored with
[`saveRDS()`](https://rdrr.io/r/base/readRDS.html) directly.
`pinn_save()` stores the network weights as plain arrays alongside the
rest of the fit, and `pinn_load()` rebuilds the network.

## Usage

``` r
pinn_save(fit, path)

pinn_load(path)
```

## Arguments

- fit:

  A `pinn_fit`.

- path:

  File path, conventionally ending in `.rds`.

## Value

`pinn_save()` returns `path` invisibly; `pinn_load()` returns a
`pinn_fit`.
