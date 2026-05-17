plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.frontend"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    externalNativeBuild {
        cmake {
            version = "3.31.6"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.frontend"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            externalNativeBuild {
                cmake {
                    arguments(
                        "-DCMAKE_C_COMPILER_WORKS=TRUE",
                        "-DCMAKE_CXX_COMPILER_WORKS=TRUE",
                        "-DCMAKE_C_ABI_COMPILED=TRUE",
                        "-DCMAKE_CXX_ABI_COMPILED=TRUE"
                    )
                }
            }
        }
        release {
            signingConfig = signingConfigs.getByName("debug")
            externalNativeBuild {
                cmake {
                    arguments(
                        "-DCMAKE_C_COMPILER_WORKS=TRUE",
                        "-DCMAKE_CXX_COMPILER_WORKS=TRUE",
                        "-DCMAKE_C_ABI_COMPILED=TRUE",
                        "-DCMAKE_CXX_ABI_COMPILED=TRUE"
                    )
                }
            }
        }
    }
}

flutter {
    source = "../.."
}
