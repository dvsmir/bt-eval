plugins {
    id("fleet.java-component")
}

dependencies {
    implementation(project(":fleet-core"))
    implementation(project(":fleet-ingest"))
    implementation(libs.acme.json)
}
