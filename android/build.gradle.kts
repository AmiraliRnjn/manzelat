allprojects {

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

subprojects {
    configurations.configureEach {
        resolutionStrategy.dependencySubstitution {
            substitute(module("androidx.camera:camera-core"))
                .using(module("androidx.camera:camera-core:1.6.1"))
                .because("Ensures correct transitive dependencies in Gradle 9")
        }
    }
    
    // تزریق مستقیم به تمام ماژول‌های کتابخانه‌ای اندروید
    pluginManager.withPlugin("com.android.library") {
        dependencies {
            add("implementation", "androidx.concurrent:concurrent-futures:1.2.0")
        }
    }
}

