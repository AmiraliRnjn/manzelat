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

// --- بلاک جدید: از اینجا شروع می‌شود ---
subprojects {
    // اجبار compileOptions به JVM 17 برای همه‌ی ماژول‌های کتابخانه‌ای اندروید
    // (پلاگین‌هایی مثل receive_sharing_intent، nfc_manager، share_plus)،
    // دقیقاً هم‌سطح با app/build.gradle.kts — تا سمت جاوا هم دیگر روی ۱۱ نماند.
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }

    // اجبار سمت کاتلین به همان JVM 17
    plugins.withId("org.jetbrains.kotlin.android") {
        extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}
// --- بلاک جدید: تا اینجا ---