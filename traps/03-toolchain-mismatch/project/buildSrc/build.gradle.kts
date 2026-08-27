plugins {
    id("java-gradle-plugin")
}

gradlePlugin {
    plugins {
        create("javaBase") {
            id = "telemetry.java-base"
            implementationClass = "telemetry.conventions.JavaBaseConventionPlugin"
        }
        create("library") {
            id = "telemetry.library"
            implementationClass = "telemetry.conventions.LibraryConventionPlugin"
        }
    }
}
