plugins {
    `java-gradle-plugin`
}

gradlePlugin {
    plugins {
        create("javaLibraryConventions") {
            id = "shopkit.java-library-conventions"
            implementationClass = "com.shopkit.conventions.JavaLibraryConventionsPlugin"
        }
        create("testingConventions") {
            id = "shopkit.testing-conventions"
            implementationClass = "com.shopkit.conventions.TestingConventionsPlugin"
        }
    }
}
