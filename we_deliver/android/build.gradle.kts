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

subprojects {
    val project = this
    val configureNamespace = {
        if (project.extensions.findByName("android") != null) {
            val androidExtension = project.extensions.getByName("android")
            try {
                val getNamespace = androidExtension.javaClass.getMethod("getNamespace")
                val currentNamespace = getNamespace.invoke(androidExtension)
                if (currentNamespace == null) {
                    val setNamespace = androidExtension.javaClass.getMethod("setNamespace", String::class.java)
                    val ns = project.group.toString().ifEmpty { "com.example.${project.name.replace("-", "_").replace(":", "_")}" }
                    setNamespace.invoke(androidExtension, ns)
                }
            } catch (e: Exception) {
                // Fallback / Ignore
            }
        }
    }

    if (project.state.executed) {
        configureNamespace()
    } else {
        project.afterEvaluate {
            configureNamespace()
        }
    }
}

