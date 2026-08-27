plugins {
    id("telemetry.java-base")
    application
}

description = "Console entry point of the telemetry tooling."

dependencies {
    implementation(project(":pipeline"))
}

application {
    mainClass = "telemetry.app.Main"
}

val smokeTest by tasks.registering(JavaExec::class) {
    group = "verification"
    description = "Runs the console entry point once."
    mainClass = "telemetry.app.Main"
    classpath = sourceSets["main"].runtimeClasspath
    javaLauncher = javaToolchains.launcherFor(java.toolchain)
}

tasks.named("check") {
    dependsOn(smokeTest)
}
