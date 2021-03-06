# Create a stack object
# In version 2.0, we've inlined the randomOrder function
Stack <- function() {
  s <- numeric()
  push <- function(val) s <<- c(val, s)
  pop <- function() {
    val <- s[1]
    s <<- s[-1]
    val
  }
  showRandom <- function() print(randomOrder2(s))

  list(push = push, pop = pop, showRandom = showRandom)
}

# Randomize the order of a list. This is an internal, non-exported function.
randomOrder2 <- function(x) x[sample(length(x))]
