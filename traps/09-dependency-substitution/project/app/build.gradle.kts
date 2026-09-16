plugins {
    application
}

group = "com.example.shop"
version = rootProject.version

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(21))
    }
}

application {
    mainClass.set("com.example.shop.App")
}

dependencies {
    implementation(libs.widgets)
}
