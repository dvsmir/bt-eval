plugins {
    id("telemetry.library")
}

description = "Rollups for the operator report."

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

dependencies {
    api(project(":collector-api"))
}
