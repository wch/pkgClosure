# Tests for closures that cross packages

If you create a closure in pkgB whose enclosing environment is the pkgA namespace, does pkgB save the entire pkgA namespace when pkgB is built?

Here is the test: pkgB contains a function `funB()`, which is a closure created by calling `pkgA::makeClosure()`, with pkgA 1.0. Then pkgB is built, and the closure should capture the pkgA namespace environment. Then pkgA is upgraded to 2.0. What happens when you load pkgB and call `funB()`?

Does building pkgB save the pkgA 1.0 namespace environment (because it was captured by the `funB` closure), or is R smart enough to know not to save the pkgA 1.0 namespace inside of the built pkgB?

## Contents of the test packages

pkgA 1.0 contains the following code:

```R
#### pkgA 1.0 ####
makeClosure <- function(txt = "") {
  versionString <- "pkgA 1.0"
  function() {
    print("This closure was created in pkgA 1.0")
    print(paste0("The parent env of this closure has versionString ", versionString))
    funA()
  }
}

funA <- function() {
  print("Called funA in pkgA 1.0")
}
```


pkgB contains just `funB`, which is a closure returned by `pkgA::makeClosure()`:

```R
#### pkgB ####
funB <- makeClosure()
```


### pkgB with pkgA 1.0

We'll install the packages to a temporary directory then run `funB()`:

```R
# Install pkgA 1.0 and pkgB to a temp directory that lasts across R sessions
dir.create("~/Rtmp")
.libPaths(c("~/Rtmp", .libPaths()))

devtools::install('pkgA_1')
library(pkgA)

devtools::install('pkgB')
library(pkgB)
funB()
#> [1] "This closure was created in pkgA 1.0"
#> [1] "The parent env of this closure has versionString pkgA 1.0"
#> [1] "Called funA in pkgA 1.0"
```

Calling `funB()` does exactly what's expected. The `funB()` function was created by calling `makeClosure()` from pkgA 1.0.

### pkgB with pkgA 2.0

Now what happens if we upgrade to pkgA 2.0, and call `funB()` without rebuilding or rebuilding pkgB?

pkgA 2.0 is very similar to 1.0, except that its functions identify themselves as being from version 2.0:

```R
#### pkgA 2.0 ####
makeClosure <- function(txt = "") {
  versionString <- "pkgA 2.0"
  function() {
    print("This closure was created in pkgA 2.0")
    print(paste0("The parent env of this closure has versionString ", versionString))
    funA()
  }
}

funA <- function() {
  print("Called funA in pkgA 2.0")
}
```

Restart R and install it:

```R
#### Restart R before continuing ####

.libPaths(c("~/Rtmp", .libPaths()))
devtools::install('pkgA_2')

library(pkgB)
funB()
#> [1] "This closure was created in pkgA 1.0"
#> [1] "The parent env of this closure has versionString pkgA 1.0"
#> [1] "Called funA in pkgA 2.0"
```

The result is a mix of pkgA 1.0 and 2.0!

If we had installed pkgA 2.0 and then built and installed pkgB against it, the result is different (and what we would expect):

```R
#### Restart R before continuing ####

.libPaths(c("~/Rtmp", .libPaths()))
devtools::install('pkgA_2')
devtools::install('pkgB')

library(pkgB)
funB()
#> [1] "This closure was created in pkgA 2.0"
#> [1] "The parent env of this closure has versionString pkgA 2.0"
#> [1] "Called funA in pkgA 2.0"
```

So it matters not only what versions of packages you have installed; it also matters what versions of packages _were_ installed when you built and installed other packages.


## Conclusion

We can conclude that, when pkgB is built:

* The `funB` function body was created by pkgA 1.0, and is saved as part of pkgB.
* The parent environment for `funB` (which contains `versionString`) is also saved as part of pkgB.
* The parent of the parent environment -- which is the pkgA namespace environment -- is _not_ saved as part of pkgB.

R must know that, because the grandparent environment is the pkgA namespace, it doesn't need to save that environment in pkgB, but can dynamically assign the pkgA namespace environment to `funB` when pkgB is loaded.

This could potentially lead to a mismatch between the function body and pkgA namespace. The body of the function in pkgB might expect to find one thing in the pkgA namespace, when the pkgA namespace contains something different.

Suppose pkgA 1.0 and pkgB are on CRAN (as binary packages), and then pkgA is updated to 2.0 on CRAN. Unless pkgB is rebuilt against the new version of pkgA, it will have a mismatch between the closure's function body, and the environment. I don't think CRAN does this -- it does not rebuild all downstream dependencies when a package is updated. And I know R doesn't rebuild downstream packages when a new version of a package a is installed from source, as is always the case on Linux.

This means that if a package is used to create objects that are stored in another package, and that first package changes, it could potentially break every package that uses it. In the example here, imagine if `funA` (which is not an exported function) were removed in pkgA 3.0. In this situation, anyone who started with pkgA 1.0 or 2.0 installed, then installed pkgB, then upgraded to pkgA 3.0, would suddenly see pkgB break!

### Implications for reproducibility

In most discussions of reproducible research with R, it's assumed that if we hold the following constant, it will result in an environment with reproducible results:

* OS version (including system-level packages)
* R version
* installed package versions

An implicit assumption is that the state of a _built_ package depends only on the version of the source package; if the input is the Shiny 0.11 package, the output is always the same.

But what we've seen here is that this isn't true. The state of a built package depends on more than the state of the source package; it can also depend on the other packages used by the source package.

If we have two computers, both of which have the same OS, R version, and both have pkgA 2.0 and pkgB 1.0, we still can't be sure that they will behave the same. To ensure a reproducible environment, we would also need to record what version of pkgA was present when pkgB was built.

*****

# A more realistic example

The example above was kind of abstract. Here's a more realistic example. pkgA also has a function `Stack()`, which returns a list with functions that enclose the pkgA namespace. Here's the code from pkgA 1.0:

```R
# Create a stack object that can hold numbers
Stack <- function() {
  s <- numeric()
  push <- function(val) s <<- c(val, s)
  pop <- function() {
    val <- s[1]
    s <<- s[-1]
    val
  }
  showRandom <- function() print(randomOrder1(s))

  list(push = push, pop = pop, showRandom = showRandom)
}

# Randomize the order of a list. This is an internal, non-exported function.
randomOrder1 <- function(x) x[sample(length(x))]
```

pkgB creates a stack and exports it for the user to access:

```R
# Create a stack and populate it with a few values.
# This stack is exported so users can access it.
stackB <- Stack()

stackB$push(5)
stackB$push(6)
stackB$push(7)
```

## Installing the two packages

Now if we install pkgA 1.0 and pkgB, we can access `stackB`:

```R
#### Restart R before continuing ####

.libPaths(c("~/Rtmp", .libPaths()))
devtools::install('pkgA_1')
devtools::install('pkgB')

library(pkgB)
stackB$push(10)
stackB$showRandom()
#> [1] 10  7  5  6
```

So far, so good.

## Upgrading to pkgA 2.0

pkgA 2.0 has a small change: the `randomOrder1` function has been renamed to `randomOrder2`:

```R
# Create a stack object
# In version 2.0, we've renamed randomOrder1 to randomOrder2
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
```


Now we'll install pkgA 2.0 and try to use pkgB again:

```R
#### Restart R before continuing ####

.libPaths(c("~/Rtmp", .libPaths()))
devtools::install('pkgA_2')

library(pkgB)
stackB$push(10)
stackB$showRandom()
#> Error in print(randomOrder1(s)) : could not find function "randomOrder1"
```

pkgB is broken by the pkgA upgrade, even though the external interfaces to pkgA are completely unchanged! The only change was that an internal function was renamed.

## Fixing pkgB

The way to fix pkgB is to build it against pkgA 2.0:

```R
#### Restart R before continuing ####

.libPaths(c("~/Rtmp", .libPaths()))
devtools::install('pkgA_2')
devtools::install('pkgB')

library(pkgB)
stackB$push(10)
stackB$showRandom()
#> [1]  6  5 10  7
```

## Wrap-up

In this more realistic example, we've seen that:

* If we install pkgA 1.0 and then pkgB, it works.
* If we install pkgA 2.0 and then pkgB, it works.
* If we install pkgA 1.0, then pkgB, then pkgA 2.0, it's broken.

I didn't include a demonstration of this, but it's also true that:

* If we install pkgA 2.0, then pkgB, then pkgA 1.0, it's broken.


*****

# Cleaning up

We can restart R and delete the temporary directory where we installed the packages:

```R
#### Restart R before continuing ####
unlink("~/Rtmp", recursive = TRUE)
```
