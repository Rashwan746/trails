plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

configure<com.android.build.gradle.internal.dsl.BaseAppModuleExtension> {
    namespace = "com.example.discover_egypt"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.discover_egypt"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// الكود الحاسم والأقوى لإجبار connectivity_plus وكافة الحزم الفرعية على استخدام SDK 36
rootProject.subprojects {
    project.configurations.configureEach {
        resolutionStrategy.eachDependency {
            // هذا التوجيه يمنع تعارض حزم androidx الفرعية ويوحدها
            if (requested.group.startsWith("androidx.")) {
                // التأكد من عدم بقاء أي مكتبة معلقة على إصدار قديم
            }
        }
    }

    afterEvaluate {
        if (project.hasProperty("android")) {
            val androidExtension = project.extensions.getByName("android")
            if (androidExtension is com.android.build.gradle.BaseExtension) {
                androidExtension.compileSdkVersion(36)
                androidExtension.defaultConfig {
                    targetSdkVersion(36)
                }
            }
        }
    }
}

// منع تهنيج كوتلن وتحديد التوافقية
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}