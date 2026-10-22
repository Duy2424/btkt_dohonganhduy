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
// Một số plugin (vd tflite_flutter) đặt Java đích 11 nhưng không đặt jvmTarget cho Kotlin → Gradle báo
// "Inconsistent JVM Target". Ép Kotlin của từng plugin dùng cùng đích với Java của chính plugin đó.
subprojects {
    tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile::class.java).configureEach {
        val javaTask = project.tasks.withType(JavaCompile::class.java).findByName(name.replace("Kotlin", "JavaWithJavac"))
        val target = javaTask?.targetCompatibility ?: return@configureEach
        compilerOptions.jvmTarget.set(
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(if (target == "8") "1.8" else target),
        )
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
