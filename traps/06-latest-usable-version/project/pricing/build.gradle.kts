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

dependencies {
    api(project(":core"))
    implementation(libs.widgets)

    testImplementation(libs.junit)
}

tasks.test {
    useJUnit()
}
