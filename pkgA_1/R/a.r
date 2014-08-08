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
