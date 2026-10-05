allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// ─── PLUGIN COMPILE SDK OVERRIDE ───
// Fixes plugins that pin an old compileSdk (e.g., onnxruntime pins 33),
// which blocks the build when transitive AndroidX libs require 34+.
// Uses plugins.withId so the override applies as each plugin is applied,
// before its own build script finalizes compileSdk.
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.api.dsl.LibraryExtension> {
            compileSdk = 36
        }
    }
    plugins.withId("com.android.application") {
        extensions.configure<com.android.build.api.dsl.ApplicationExtension> {
            compileSdk = 36
        }
    }
}
// ─── ONNXRUNTIME COMPILE SDK FIX ───
// onnxruntime hardcodes compileSdkVersion 33 in its own build.gradle.
// Root-level plugins.withId overrides run too early to override it.
// This targeted afterEvaluate runs AFTER the plugin's build script sets 33,
// allowing us to override it to 36.
subprojects {
    if (project.name == "onnxruntime") {
        afterEvaluate {
            extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.apply {
                compileSdkVersion(36)
            }
        }
    }
}