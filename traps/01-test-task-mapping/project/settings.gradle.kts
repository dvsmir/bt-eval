rootProject.name = "shopkit"

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        maven {
            name = "offline"
            url = uri(rootDir.resolve("gradle/offline-repo"))
        }
    }
}

include("pricing")
include("checkout")
