plugins {
    id("shopkit.java-library-conventions")
}

description = "Turns a basket into a receipt for the storefront."

dependencies {
    api(project(":pricing"))
}
