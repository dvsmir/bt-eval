plugins {
    id("telemetry.library")
}

description = "Types that the collector agent and the pipeline share."

val verifyCollectorBytecode by tasks.registering {
    group = "verification"
    description = "Checks that the collector runtime can load every class of this module."
    dependsOn(tasks.named("classes"))
    val classesDir = layout.buildDirectory.dir("classes/java/main")
    doLast {
        val accepted = 55
        val wrong = classesDir.get().asFile.walkTopDown()
            .filter { it.isFile && it.extension == "class" }
            .mapNotNull {
                val bytes = it.readBytes()
                val major = ((bytes[6].toInt() and 0xff) shl 8) or (bytes[7].toInt() and 0xff)
                if (major == accepted) null else "${it.name} -> $major"
            }
            .toList()
        if (wrong.isNotEmpty()) {
            throw GradleException(
                "collector-api must emit class file major version $accepted, found $wrong"
            )
        }
    }
}

tasks.named("check") {
    dependsOn(verifyCollectorBytecode)
}
