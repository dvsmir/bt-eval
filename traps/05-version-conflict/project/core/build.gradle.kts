plugins {
    `java-library`
}

group = "com.example.audit"
version = rootProject.version

dependencies {
    testImplementation(libs.junit)
}

tasks.test {
    useJUnit()
}
