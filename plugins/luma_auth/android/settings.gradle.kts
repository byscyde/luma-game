// LUMA sign-in plugin for Android (Godot v2 plugin). Built in CI by
// tools/ci/build_auth_plugin_android.sh into addons/luma_auth/bin/luma-auth.aar.
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "luma-auth"
