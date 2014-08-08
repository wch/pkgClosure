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
  showRandom <- function() print(s[sample(length(s))])

  list(push = push, pop = pop, showRandom = showRandom)
}
