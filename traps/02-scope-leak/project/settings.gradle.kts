rootProject.name = "acme-ledger"

dependencyResolutionManagement {
    repositories {
        maven {
            name = "offlineRepo"
            url = uri(rootDir.resolve("gradle/offline-repo"))
        }
    }
}

include(":platform-core")
include(":ledger-service")
