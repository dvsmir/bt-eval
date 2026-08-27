plugins {
    `java-gradle-plugin`
}

group = "com.acme.fleet.build"

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(21))
    }
}

gradlePlugin {
    plugins {
        create("javaComponent") {
            id = "fleet.java-component"
            implementationClass = "fleet.build.JavaComponentPlugin"
        }
    }
}
