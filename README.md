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

# Install pkgA 2.0 ----------------------------------------------------
library(devtools)
.libPaths(c("~/Rtmp", .libPaths()))
install('pkgA_2')

library(pkgB)
funB()
#> [1] "This closure was created in pkgA 1.0"
#> [1] "The parent env of this closure has versionString pkgA 1.0"
#> [1] "Called funA in pkgA 2.0"
```

We can conclude that, when pkgB is built:

* The `funB` function body was created by pkgA 1.0, and is saved as part of pkgB.
* The parent environment for `funB` (which contains `versionString`) is also saved as part of pkgB.
* The parent of the parent environment -- which is the pkgA namespace environment -- is _not_ saved as part of pkgB.

R must know that, because the grandparent environment is the pkgA namespace, it doesn't need to save that environment in pkgB, but can dynamically assign the pkgA namespace environment to `funB` when pkgB is loaded.

This could potentially lead to a mismatch between the function body and pkgA namespace. The body of the function in pkgB might expect to find one thing in the pkgA namespace, when the pkgA namespace contains something different.


## Clean up

Finally, we can restart R and delete the temporary directory where we installed the packages:

```R
#### Restart R before continuing ####
unlink("~/Rtmp", recursive = TRUE)
```
