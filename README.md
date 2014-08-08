# Tests for closures that cross packages

If you create a closure in pkgB whose enclosing environment is the pkgA namespace, does pkgB save the entire pkgA namespace when pkgB is built?

Here is the test: pkgB contains a function `funB()` that is a closure created by calling `pkgA::makeClosure()`, with pkgA 1.0. pkgB is built, and the closure captures the pkgA namespace environment. Then pkgA is upgraded to 2.0. What happens when you load pkgB and call `funB()`?

Does building pkgB save the pkgA 1.0 namespace environment (because it was captured by the `funB` closure), or is R smart enough to know not to save the pkgA 1.0 namespace inside of the built pkgB?

## Contents of the test packages

pkgA 1.0 contains the following code:

```R
#### pkgA 1.0 ####
makeClosure <- function(txt = "") {
  function() {
    print(paste0("This closure was created in pkgA 1.0"))
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
library(devtools)
tmpdir <- "~/Rtmp"
dir.create(tmpdir)
.libPaths(c(tmpdir, .libPaths()))

install('pkgA_1')
library(pkgA)
funA()
#> [1] "Called funA in pkgA 1.0"

install('pkgB')
library(pkgB)
funB()
#> [1] "This closure was created in pkgA 1.0"
#> [1] "Called funA in pkgA 1.0"
```

Calling `funB()` does exactly what's expected. The `funB()` function was created by calling `makeClosure()` from pkgA 1.0.

### pkgB with pkgA 2.0

Now what happens if we upgrade to pkgA 2.0, and call `funB()` without rebuilding or rebuilding pkgB?

pkgA 2.0 is very similar to 1.0, except that its functions identify themselves as being from version 2.0:

```R
#### pkgA 2.0 ####
makeClosure <- function(txt = "") {
  function() {
    print(paste0("This closure was created in pkgA 2.0"))
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

# Install pkgA 2.0 ----------------------------------------------------
library(devtools)
.libPaths(c("~/Rtmp", .libPaths()))
install('pkgA_2')

library(pkgB)
funB()
#> [1] "This closure was created in pkgA 1.0"
#> [1] "Called funA in pkgA 2.0"
```

We can conclude that although the `funB` function body was created by pkgA 1.0, and is saved as part of pkgB, the enclosing environment for `funB` is *not* saved as part of pkgB. R must know that, because the enclosing environment is the pkgA namespace, it doesn't need to save that environment in pkgB, but can dynamically assign the pkgA namespace environment to `funB` when pkgB is loaded.

This could potentially lead to a mismatch between the function body and pkgA namespace. The body of the function in pkgB might expect to find one thing in the pkgA namespace, when the pkgA namespace contains something different.
