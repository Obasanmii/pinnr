test_that("pinn_domain stores ranges in order", {
  dom <- pinn_domain(x = c(-1, 1), t = c(0, 2))
  expect_s3_class(dom, "pinn_domain")
  expect_equal(dom$vars, c("x", "t"))
  expect_equal(unname(dom$lower), c(-1, 0))
  expect_equal(unname(dom$upper), c(1, 2))
  expect_output(print(dom), "x in \\[-1, 1\\]")
})

test_that("pinn_domain rejects bad input", {
  expect_error(pinn_domain(), "at least one variable")
  expect_error(pinn_domain(c(0, 1)), "named")
  expect_error(pinn_domain(x = c(1, 0)), "lower bound")
  expect_error(pinn_domain(x = c(0, Inf)), "finite")
  expect_error(pinn_domain(x = 1), "finite numeric range")
  expect_error(pinn_domain(x = c(0, 1), x = c(0, 2)), "Duplicated")
  expect_error(pinn_domain(d = c(0, 1)), "reserved")
})

test_that("pinn_sample stays inside the domain", {
  set.seed(1)
  dom <- pinn_domain(x = c(-2, 3), t = c(10, 11))
  for (m in c("lhs", "uniform")) {
    s <- pinn_sample(500, dom, method = m)
    expect_equal(dim(s), c(500, 2))
    expect_true(all(s$x >= -2 & s$x <= 3))
    expect_true(all(s$t >= 10 & s$t <= 11))
  }
})

test_that("Latin hypercube puts one point in each stratum", {
  set.seed(42)
  s <- pinn_sample(50, pinn_domain(x = c(0, 1)), method = "lhs")
  strata <- floor(s$x * 50)
  expect_setequal(strata, 0:49)
})

test_that("fixed values are honoured and split evenly", {
  set.seed(1)
  dom <- pinn_domain(x = c(0, 1), t = c(0, 5))
  s <- pinn_sample(10, dom, fixed = list(x = c(0, 1)))
  expect_equal(sort(unique(s$x)), c(0, 1))
  expect_equal(as.vector(table(s$x)), c(5, 5))
  s3 <- pinn_sample(7, dom, fixed = list(x = c(0, 0.5, 1)))
  expect_equal(nrow(s3), 7)
  expect_true(all(table(s3$x) >= 2))
  expect_error(pinn_sample(5, dom, fixed = list(z = 0)), "Unknown variable")
  # every fixed value gets at least one point, even when n is small
  s1 <- pinn_sample(1, dom, fixed = list(x = c(0, 1)))
  expect_equal(sort(s1$x), c(0, 1))
  expect_error(pinn_sample(0, dom), "whole number")
})

test_that("several fixed variables use every combination", {
  set.seed(1)
  dom <- pinn_domain(x = c(0, 1), y = c(0, 2), t = c(0, 5))
  s <- pinn_sample(8, dom, fixed = list(x = c(0, 1), y = c(0, 2)))
  expect_equal(nrow(s), 8)
  corners <- table(paste(s$x, s$y))
  expect_setequal(names(corners), c("0 0", "1 0", "0 2", "1 2"))
  expect_true(all(corners == 2))
  expect_true(all(s$t >= 0 & s$t <= 5))
  # a single value per variable is a single location
  s2 <- pinn_sample(5, dom, fixed = list(x = 1, y = 0))
  expect_true(all(s2$x == 1 & s2$y == 0))
})
