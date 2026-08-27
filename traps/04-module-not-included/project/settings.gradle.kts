rootProject.name = "fleet"

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        maven {
            name = "acmeInternal"
            url = rootDir.resolve("gradle/repo").toURI()
        }
    }
}

val componentsDir = rootDir.resolve("components")

providers.gradleProperty("fleet.components").get()
    .split(",")
    .map { it.trim() }
    .filter { it.isNotEmpty() }
    .forEach { component ->
        val path = ":fleet-$component"
        include(path)
        project(path).projectDir = componentsDir.resolve(component)
    }
