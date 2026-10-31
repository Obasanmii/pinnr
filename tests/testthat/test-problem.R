heat_problem <- function(...) {
  pinn_problem(
    domain = pinn_domain(x = c(0, 1), t = c(0, 1)),
    outputs = "u",
    residual = function(u, x, t, a, d) d(u, t) - a * d(u, x, x),
    conditions = list(
      pinn_initial(function(x) sin(pi * x), time = "t"),
      pinn_dirichlet(where = list(x = "both"), value = 0)
    ),
    parms = list(a = 0.1),
    ...
  )
}

test_that("pinn_problem builds a valid problem", {
  p <- heat_problem()
  expect_s3_class(p, "pinn_problem")
  expect_length(p$conditions, 2)
  expect_equal(p$conditions[[2]]$where, list(x = c(0, 1)))
  expect_output(print(p), "Outputs:    u")
  expect_output(print(p), "a = 0.1")
})

test_that("a plain list works as a domain and a single condition is wrapped", {
  p <- pinn_problem(list(x = c(0, 1)), "u", function(u, x, d) d(u, x) - 1,
                    conditions = pinn_dirichlet(list(x = 0), 0))
  expect_s3_class(p$domain, "pinn_domain")
  expect_length(p$conditions, 1)
})

test_that("pinn_problem validates names and inputs", {
  res <- function(u, x, d) d(u, x)
  dom <- pinn_domain(x = c(0, 1))
  cnd <- pinn_dirichlet(list(x = 0), 0)
  expect_error(pinn_problem(dom, character(), res, cnd), "output names")
  expect_error(pinn_problem(dom, "x", res, cnd), "unique across")
  expect_error(pinn_problem(dom, "u", res, cnd, parms = list(u = 1)), "unique across")
  expect_error(pinn_problem(dom, "u", "not a function", cnd), "must be a function")
  expect_error(pinn_problem(dom, "u", res, list(1)), "conditions")
  expect_error(pinn_problem(dom, "u", res, cnd, parms = list(k = "a")), "numeric")
  expect_error(pinn_problem(dom, "d", res, cnd), "reserved")
  expect_warning(pinn_problem(dom, "u", res), "not unique")
})

test_that("unknown parameters are checked", {
  res <- function(u, x, k, d) d(u, x) + k * u
  dom <- pinn_domain(x = c(0, 1))
  cnd <- pinn_dirichlet(list(x = 0), 1)
  p <- pinn_problem(dom, "u", res, cnd, unknown = c(k = 2))
  expect_equal(p$unknown$positive, c(k = TRUE))
  p2 <- pinn_problem(dom, "u", res, cnd, unknown = c(k = -2), positive = FALSE)
  expect_equal(p2$unknown$positive, c(k = FALSE))
  expect_error(pinn_problem(dom, "u", res, cnd, unknown = c(k = -2)), "> 0")
  expect_error(pinn_problem(dom, "u", res, cnd, unknown = c(k = 1),
                            positive = c(j = TRUE)), "names unknown")
  expect_output(print(p), "k \\(start 2\\)")
})

test_that("data are checked and cleaned", {
  res <- function(u, v, x, d) list(d(u, x), d(v, x))
  dom <- pinn_domain(x = c(0, 1))
  dat <- data.frame(x = c(0.1, 0.2, 0.3), u = c(1, NA, NA), v = c(NA, 2, NA),
                    other = 1)
  p <- pinn_problem(dom, c("u", "v"), res, data = dat)
  expect_equal(names(p$data), c("x", "u", "v"))
  expect_equal(nrow(p$data), 2)  # the all-NA row is dropped
  expect_output(print(p), "2 rows observing u, v")
  expect_error(pinn_problem(dom, "u", res, data = data.frame(u = 1)), "domain variable")
  expect_error(pinn_problem(dom, "u", res, data = data.frame(x = 1)), "output column")
  # an output column with no observations is dropped, numeric or logical NA
  p2 <- pinn_problem(dom, c("u", "v"), res,
                     data = data.frame(x = c(0.1, 0.2), u = c(1, 2), v = NA_real_))
  expect_equal(names(p2$data), c("x", "u"))
  p3 <- pinn_problem(dom, c("u", "v"), res,
                     data = data.frame(x = c(0.1, 0.2), u = c(1, 2), v = NA))
  expect_equal(names(p3$data), c("x", "u"))
  expect_error(pinn_problem(dom, "u", res, data = data.frame(x = 1, u = NA_real_)),
               "output column with observed values")
  expect_error(pinn_problem(dom, "u", res, data = data.frame(x = c(NA, 1), u = 1)),
               "missing values")
  expect_error(pinn_problem(dom, "u", res, data = data.frame(x = "a", u = 1)),
               "numeric")
})

test_that("call_with_pool matches arguments by name", {
  pool <- list(u = 1, x = 2, k = 3)
  expect_equal(pinnr:::call_with_pool(function(u, k) u + k, pool, "f"), 4)
  expect_equal(pinnr:::call_with_pool(function(...) length(list(...)), pool, "f"), 3)
  expect_equal(pinnr:::call_with_pool(function(u, z = 10) u + z, pool, "f"), 11)
  expect_error(pinnr:::call_with_pool(function(u, w) u, pool, "My function"),
               "My function uses argument\\(s\\) `w`")
})

test_that("residual output is coerced to a list", {
  expect_equal(pinnr:::as_residual_list(list(1, 2), "r"), list(1, 2))
  expect_error(pinnr:::as_residual_list("a", "The residual"), "torch tensor")
})

test_that("1D solution plots use a dense grid", {
  p <- pinn_ode(function(t, y, parms) list(-y), c(y = 1), times = c(0, 5))
  g <- pinnr:::line_grid(p$domain)
  expect_named(g, "time")
  expect_equal(nrow(g), 201)
  expect_equal(range(g$time), c(0, 5))
})
