plugins {
    `java-gradle-plugin`
}

gradlePlugin {
    plugins {
        register("serviceConventions") {
            id = "com.acme.service-conventions"
            implementationClass = "com.acme.conventions.ServiceConventionsPlugin"
        }
    }
}
