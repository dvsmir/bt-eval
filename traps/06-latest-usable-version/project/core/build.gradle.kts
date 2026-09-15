plugins {
    `java-library`
}

group = "com.example.shop"
version = rootProject.version

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(21))
    }
}
