dom <- pinn_domain(x = c(0, 2), t = c(0, 1))

test_that("constructors build condition specs", {
  d <- pinn_dirichlet(list(x = "both"), 0)
  expect_s3_class(d, "pinn_condition")
  expect_equal(d$type, "dirichlet")
  n <- pinn_neumann(list(x = "upper"), along = "x", value = 1, n = 20)
  expect_equal(n$along, "x")
  expect_equal(n$n, 20L)
  i <- pinn_initial(function(x) x^2, time = "t")
  expect_equal(i$where, list(t = "lower"))
  expect_equal(i$name, "initial")
  cnd <- pinn_condition(list(x = 0), function(u) u)
  expect_equal(cnd$type, "custom")
  expect_output(print(d), "dirichlet at x = both")
})

test_that("constructors validate input", {
  expect_error(pinn_dirichlet(c(x = 0)), "named list")
  expect_error(pinn_dirichlet(list(x = "middle")), "lower")
  expect_error(pinn_dirichlet(list(x = 0), value = "a"), "value")
  expect_error(pinn_dirichlet(list(x = 0), n = 0), "whole number")
  expect_error(pinn_dirichlet(list(x = 0), weight = -1), "positive")
  expect_error(pinn_neumann(list(x = 0), along = c("x", "t")), "along")
  expect_error(pinn_condition(list(x = 0), fn = 1), "function")
})

test_that("locations resolve to numbers and are checked", {
  expect_equal(pinnr:::resolve_where(list(x = "both"), dom), list(x = c(0, 2)))
  expect_equal(pinnr:::resolve_where(list(t = "upper"), dom), list(t = 1))
  expect_equal(pinnr:::resolve_where(list(x = 1.5), dom), list(x = 1.5))
  expect_error(pinnr:::resolve_where(list(x = 3), dom), "outside the domain")
  expect_error(pinnr:::resolve_where(list(z = 0), dom), "unknown domain variable")
})

test_that("Dirichlet residuals use values by output and by function", {
  cnd <- pinnr:::resolve_condition(
    pinn_dirichlet(list(x = 0), value = c(u = 1, v = 2)), dom, c("u", "v"), 1)
  r <- cnd$fn(list(u = 5, v = 7, x = 0, t = 0.5))
  expect_equal(unlist(r), c(4, 5))

  cnd2 <- pinnr:::resolve_condition(
    pinn_initial(function(x) 3 * x, time = "t"), dom, "u", 2)
  r2 <- cnd2$fn(list(u = c(1, 1), x = c(1, 2), t = c(0, 0)))
  expect_equal(r2[[1]], c(-2, -5))

  expect_error(
    pinnr:::resolve_condition(pinn_dirichlet(list(x = 0), output = "w"),
                              dom, "u", 1),
    "unknown output")
  expect_error(
    pinnr:::resolve_condition(pinn_dirichlet(list(x = 0), value = c(1, 2, 3)),
                              dom, c("u", "v"), 1),
    "one entry per output")
})

test_that("Neumann and custom residuals call d and match names", {
  fake_d <- function(f, x) 10 * f
  cnd <- pinnr:::resolve_condition(
    pinn_neumann(list(x = "upper"), along = "x", value = 1), dom, "u", 1)
  expect_equal(cnd$fn(list(u = 2, x = 2, t = 0, d = fake_d))[[1]], 19)

  cust <- pinnr:::resolve_condition(
    pinn_condition(list(x = 0), function(u, x, k) u + k * x), dom, "u", 1)
  expect_equal(cust$fn(list(u = 1, x = 2, t = 0, k = 3))[[1]], 7)
  expect_error(cust$fn(list(u = 1, x = 2, t = 0)), "`k`")
  expect_error(
    pinnr:::resolve_condition(pinn_neumann(list(x = 0), along = "y"), dom, "u", 1),
    "not a domain variable")
})
