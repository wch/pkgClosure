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


## Cleaning up

We can restart R and delete the temporary directory where we installed the packages:

```R
#### Restart R before continuing ####
unlink("~/Rtmp", recursive = TRUE)
```
