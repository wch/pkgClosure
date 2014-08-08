makeClosure <- function(txt = "") {
  function() {
    print(paste0("This closure was created in pkgA 1.0"))
    funA()
  }
}

funA <- function() {
  print("Called funA in pkgA 1.0")
}
