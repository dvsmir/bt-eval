plugins {
    id("telemetry.library")
}

description = "Buffering and aggregation for collected measurements."

dependencies {
    api(project(":collector-api"))
}
