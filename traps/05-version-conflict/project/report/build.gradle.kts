plugins {
    `java-library`
    application
}

group = "com.example.audit"
version = rootProject.version

dependencies {
    api(project(":core"))
    implementation(libs.fakelib)
    implementation(libs.acme.audit)

    testImplementation(libs.junit)
}

application {
    mainClass.set("com.example.audit.report.Main")
}

tasks.test {
    useJUnit()
}
