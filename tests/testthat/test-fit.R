# Training tests. They need the torch backend and are skipped without it.
# Settings are small so the whole file runs in about a minute on a CPU.

decay <- function(t, y, parms) list(-parms["k"] * y)

test_that("an ODE forward problem is solved accurately", {
  skip_if_no_torch()
  prob <- pinn_ode(decay, y0 = c(y = 1), times = seq(0, 5, by = 0.25),
                   parms = c(k = 0.5))
  fit <- pinn_fit(prob, hidden = c(16, 16), epochs = 1500, seed = 1,
                  verbose = FALSE)
  expect_s3_class(fit, "pinn_fit")
  pr <- predict(fit)
  expect_equal(pr$time, seq(0, 5, by = 0.25))
  expect_lt(max(abs(pr$y - exp(-0.5 * pr$time))), 0.05)
  # the hard initial condition is exact
  expect_equal(predict(fit, data.frame(time = 0))$y, 1, tolerance = 1e-6)
  expect_length(coef(fit), 0)
  expect_true(all(c("step", "phase", "total", "residual") %in% names(fit$history)))
})

test_that("an unknown parameter is recovered from data", {
  skip_if_no_torch()
  times <- seq(0, 4, by = 0.4)
  obs <- data.frame(time = times, y = exp(-0.7 * times))
  prob <- pinn_ode(decay, y0 = c(y = 1), times = times, unknown = c(k = 0.3),
                   data = obs)
  fit <- pinn_fit(prob, hidden = c(16, 16), epochs = 2500, seed = 2,
                  verbose = FALSE)
  expect_named(coef(fit), "k")
  expect_lt(abs(coef(fit)[["k"]] - 0.7), 0.05)
  expect_true("k" %in% names(fit$history))
})

test_that("the heat equation is solved on a 2D domain", {
  skip_if_no_torch()
  prob <- pinn_problem(
    domain = pinn_domain(x = c(0, 1), t = c(0, 1)),
    outputs = "u",
    residual = function(u, x, t, a, d) d(u, t) - a * d(u, x, x),
    conditions = list(
      pinn_initial(function(x) sin(pi * x), time = "t"),
      pinn_dirichlet(where = list(x = "both"), value = 0)
    ),
    parms = list(a = 0.1)
  )
  fit <- pinn_fit(prob, hidden = c(20, 20), epochs = 2000, n_collocation = 500,
                  seed = 1, verbose = FALSE)
  grid <- expand.grid(x = seq(0, 1, length.out = 21), t = seq(0, 1, length.out = 21))
  pr <- predict(fit, grid)
  exact <- exp(-0.1 * pi^2 * grid$t) * sin(pi * grid$x)
  expect_lt(max(abs(pr$u - exact)), 0.1)
  res <- residuals(fit, grid)
  expect_named(res, c("x", "t", "residual_u"))
  expect_lt(mean(abs(res$residual_u)), 0.1)
})

test_that("Neumann conditions are enforced", {
  skip_if_no_torch()
  # u'' = 2 on [0, 1], u(0) = 0, u'(1) = 2  ->  u = x^2
  prob <- pinn_problem(
    domain = pinn_domain(x = c(0, 1)),
    outputs = "u",
    residual = function(u, x, d) d(u, x, x) - 2,
    conditions = list(
      pinn_dirichlet(list(x = "lower"), 0, n = 10),
      pinn_neumann(list(x = "upper"), along = "x", value = 2, n = 10)
    )
  )
  fit <- pinn_fit(prob, hidden = c(16, 16), epochs = 2000, n_collocation = 200,
                  seed = 3, verbose = FALSE)
  pr <- predict(fit, data.frame(x = seq(0, 1, by = 0.1)))
  expect_lt(max(abs(pr$u - pr$x^2)), 0.05)
})

test_that("systems, transforms and the d operator work together", {
  skip_if_no_torch()
  # u' = v, v' = -u with u(0) = 0, v(0) = 1  ->  u = sin(t), v = cos(t)
  prob <- pinn_problem(
    domain = pinn_domain(t = c(0, pi)),
    outputs = c("u", "v"),
    residual = function(u, v, t, d) list(d(u, t) - v, d(v, t) + u),
    transform = function(u, v, t) list(u = t * u, v = 1 + t * v)
  )
  fit <- pinn_fit(prob, hidden = c(16, 16), epochs = 2000, n_collocation = 300,
                  seed = 4, verbose = FALSE)
  tt <- seq(0, pi, length.out = 30)
  pr <- predict(fit, data.frame(t = tt))
  expect_lt(max(abs(pr$u - sin(tt))), 0.05)
  expect_lt(max(abs(pr$v - cos(tt))), 0.05)
  expect_named(residuals(fit, data.frame(t = tt)),
               c("t", "residual_u", "residual_v"))
})

test_that("print, summary, plot and save/load work", {
  skip_if_no_torch()
  prob <- pinn_ode(decay, y0 = c(y = 1), times = c(0, 2), parms = c(k = 1))
  fit <- pinn_fit(prob, hidden = c(8), epochs = 100, seed = 1, verbose = FALSE)
  expect_output(print(fit), "<pinn_fit>")
  expect_output(print(summary(fit)), "Loss fell")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_invisible(plot(fit))
  expect_invisible(plot(fit, type = "solution"))
  expect_error(plot(fit, type = "parameters"), "no unknown")

  path <- tempfile(fileext = ".rds")
  pinn_save(fit, path)
  fit2 <- pinn_load(path)
  nd <- data.frame(time = c(0.3, 1.7))
  expect_equal(predict(fit2, nd), predict(fit, nd), tolerance = 1e-6)
  expect_error(pinn_load({ p <- tempfile(); saveRDS(1, p); p }), "pinn_save")
})

test_that("time windows march across the horizon", {
  skip_if_no_torch()
  prob <- pinn_ode(decay, y0 = c(y = 1), times = seq(0, 6, by = 0.5),
                   parms = c(k = 0.5))
  fit <- pinn_fit(prob, hidden = c(16, 16), epochs = 1000, seed = 1,
                  windows = 3, verbose = FALSE)
  expect_length(fit$windows, 3)
  expect_equal(fit$breaks, c(0, 2, 4, 6))
  pr <- predict(fit)
  expect_equal(nrow(pr), 13)
  expect_lt(max(abs(pr$y - exp(-0.5 * pr$time))), 0.05)
  expect_true("window" %in% names(fit$history))
  expect_null(fit$windows[[1]]$call)
  expect_false(fit$diverged)
  expect_output(print(fit), "3 windows")

  path <- tempfile(fileext = ".rds")
  pinn_save(fit, path)
  expect_equal(predict(pinn_load(path)), pr, tolerance = 1e-6)
})

test_that("optional training modes run", {
  skip_if_no_torch()
  prob <- pinn_ode(decay, y0 = c(y = 1), times = c(0, 2), parms = c(k = 1))
  fit <- pinn_fit(prob, hidden = c(8, 8), epochs = 100, lbfgs_iter = 20,
                  precision = "float64", resample_every = 25,
                  sampling = "uniform", activation = "sin", seed = 1,
                  verbose = FALSE)
  expect_true(is.finite(fit$final_loss[["total"]]))
  expect_true(any(fit$history$phase == "lbfgs"))
})

test_that("bad residual functions give clear errors", {
  skip_if_no_torch()
  prob <- pinn_problem(pinn_domain(x = c(0, 1)), "u",
                       residual = function(u, x) "oops",
                       conditions = pinn_dirichlet(list(x = 0), 0))
  expect_error(pinn_fit(prob, epochs = 1, verbose = FALSE), "must return a torch tensor")
  prob2 <- pinn_problem(pinn_domain(x = c(0, 1)), "u",
                        residual = function(u, y) u,
                        conditions = pinn_dirichlet(list(x = 0), 0))
  expect_error(pinn_fit(prob2, epochs = 1, verbose = FALSE), "`y`")
})

test_that("a fixed seed makes training reproducible", {
  skip_if_no_torch()
  prob <- pinn_ode(decay, y0 = c(y = 1), times = c(0, 2), parms = c(k = 1))
  a <- pinn_fit(prob, hidden = 8, epochs = 50, seed = 7, verbose = FALSE)
  b <- pinn_fit(prob, hidden = 8, epochs = 50, seed = 7, verbose = FALSE)
  expect_equal(a$final_loss, b$final_loss)
})

test_that("a diverging loss returns the best weights with a warning", {
  skip_if_no_torch()
  # the residual turns NaN for a few evaluations, poisoning the weights
  calls <- 0
  res <- function(u, x, d) {
    calls <<- calls + 1
    r <- d(u, x) - 1
    if (calls %in% 101:105) r * NaN else r
  }
  prob <- pinn_problem(pinn_domain(x = c(0, 1)), "u", res,
                       conditions = pinn_dirichlet(list(x = 0), 0, n = 5))
  expect_warning(
    fit <- pinn_fit(prob, hidden = 8, epochs = 300, lbfgs_iter = 10,
                    n_collocation = 50, seed = 1, verbose = FALSE),
    "lowest loss")
  expect_true(fit$diverged)
  expect_true(is.finite(fit$final_loss[["total"]]))
  expect_false(any(fit$history$phase == "lbfgs"))
  expect_true(all(is.finite(predict(fit, data.frame(x = c(0, 0.5, 1)))$u)))
  expect_output(print(fit), "diverged")

  # nothing to fall back on when the very first loss is not finite
  bad <- pinn_problem(pinn_domain(x = c(0, 1)), "u",
                      function(u, x, d) d(u, x) * NaN,
                      conditions = pinn_dirichlet(list(x = 0), 0, n = 5))
  expect_error(pinn_fit(bad, hidden = 8, epochs = 20, verbose = FALSE),
               "loss became NaN")
})

test_that("an unobserved output column does not break the data loss", {
  skip_if_no_torch()
  two <- function(t, y, parms) list(c(-y[1], y[1] - y[2]))
  obs <- data.frame(time = seq(0, 2, by = 0.5), A = exp(-seq(0, 2, by = 0.5)),
                    B = NA_real_)
  prob <- pinn_ode(two, c(A = 1, B = 0), c(0, 2), data = obs)
  fit <- pinn_fit(prob, hidden = 8, epochs = 50, seed = 1, verbose = FALSE)
  expect_true(is.finite(fit$final_loss[["data"]]))
})
