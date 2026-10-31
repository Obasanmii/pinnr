`%||%` <- function(a, b) if (is.null(a)) b else a

# Names a user may not use for variables, outputs or parameters, because
# they are supplied to user functions with a fixed meaning.
reserved_names <- c("d", "...")

check_names <- function(x, what) {
  nm <- names(x)
  if (length(x) == 0) return(invisible(character()))
  if (is.null(nm) || anyNA(nm) || any(nm == "")) {
    stop(sprintf("All %s must be named.", what), call. = FALSE)
  }
  if (anyDuplicated(nm)) {
    stop(sprintf("Duplicated %s name(s): %s.", what,
                 paste(unique(nm[duplicated(nm)]), collapse = ", ")),
         call. = FALSE)
  }
  bad <- intersect(nm, reserved_names)
  if (length(bad)) {
    stop(sprintf("'%s' is reserved and cannot be used as a %s name.",
                 bad[1], what), call. = FALSE)
  }
  if (any(!grepl("^[.A-Za-z][._A-Za-z0-9]*$", nm))) {
    stop(sprintf("%s names must be syntactic R names (got: %s).", what,
                 paste(nm[!grepl("^[.A-Za-z][._A-Za-z0-9]*$", nm)],
                       collapse = ", ")),
         call. = FALSE)
  }
  invisible(nm)
}

check_count <- function(x, what, min = 1) {
  if (!is.numeric(x) || length(x) != 1 || !is.finite(x) || x < min ||
      x != round(x)) {
    stop(sprintf("`%s` must be a whole number >= %s.", what, min),
         call. = FALSE)
  }
  as.integer(x)
}

check_positive <- function(x, what) {
  if (!is.numeric(x) || length(x) != 1 || !is.finite(x) || x <= 0) {
    stop(sprintf("`%s` must be a single positive number.", what),
         call. = FALSE)
  }
  x
}

# Call a user function, matching its formal arguments by name against a
# pool of available objects (outputs, coordinates, parameters, `d`).
# Functions with `...` receive the whole pool.
call_with_pool <- function(fn, pool, what) {
  fa <- formals(fn)
  nms <- names(fa)
  if ("..." %in% nms) {
    return(do.call(fn, pool))
  }
  has_default <- vapply(fa, function(a) !identical(a, quote(expr = )),
                        logical(1))
  missing <- setdiff(nms[!has_default], names(pool))
  if (length(missing)) {
    stop(sprintf(
      "%s uses argument(s) %s, which match no variable, output or parameter. Available names: %s.",
      what,
      paste0("`", missing, "`", collapse = ", "),
      paste(setdiff(names(pool), "..."), collapse = ", ")
    ), call. = FALSE)
  }
  do.call(fn, pool[intersect(nms, names(pool))])
}

is_tensor <- function(x) inherits(x, "torch_tensor")

# Coerce the result of a residual-type function to a list of tensors.
as_residual_list <- function(r, what) {
  if (is_tensor(r) || is.numeric(r)) return(list(r))
  if (is.list(r) && length(r) > 0) {
    ok <- vapply(r, function(e) is_tensor(e) || is.numeric(e), logical(1))
    if (all(ok)) return(r)
  }
  stop(sprintf(
    "%s must return a torch tensor or a list of tensors (got an object of class '%s').",
    what, class(r)[1]
  ), call. = FALSE)
}

torch_dtype_from <- function(precision) {
  switch(precision,
         float32 = torch_float32(),
         float64 = torch_float64(),
         stop("`precision` must be \"float32\" or \"float64\".", call. = FALSE))
}

fmt_num <- function(x) trimws(formatC(x, digits = 4, format = "g"))
