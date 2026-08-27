rootProject.name = "audit-tools"

val localRepoUri = rootDir.resolve("local-repo").toURI()

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        maven {
            name = "localRepo"
            url = localRepoUri
        }
    }
}

include(":core")
include(":report")
