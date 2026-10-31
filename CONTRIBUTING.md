# Contributing to pinnr

Thanks for considering a contribution.

## Reporting problems

Open an issue with a minimal reproducible example (the problem definition
and the `pinn_fit()` call), the output of `sessionInfo()`, and
`torch::torch_is_installed()`.

## Asking for help

Questions about using `pinnr` are welcome as GitHub issues with the
"question" label.

## Pull requests

1. Open an issue first for anything larger than a small fix.
2. Fork the repository and create a branch.
3. Add tests in `tests/testthat/` for new behaviour. Tests that train a
   network must call `skip_if_no_torch()` and should run in seconds.
4. Document functions with roxygen2 and run `devtools::document()`.
5. Run `devtools::check()` and make sure it passes.
6. Add a bullet to `NEWS.md`.

Please be respectful in all interactions.
