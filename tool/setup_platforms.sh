#!/usr/bin/env bash
# Creates the rest of the android/ folder with `flutter create`.
#
# The repo already holds the Android files this app customises
# (AndroidManifest.xml, MainActivity.kt, file_paths.xml). `flutter create`
# never overwrites files that exist, so it only adds the missing ones
# (Gradle files, launcher icons, themes).
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create --platforms=android --org com.fansconnector --project-name fc_leads .

# MainActivity uses androidx FileProvider to hand the graphic to WhatsApp
# and email apps. Make sure androidx.core is on the classpath.
GRADLE_KTS="android/app/build.gradle.kts"
GRADLE_GROOVY="android/app/build.gradle"
# Scheduled notifications (flutter_local_notifications) need core library
# desugaring.
if [ -f "$GRADLE_KTS" ] && ! grep -q 'androidx.core:core' "$GRADLE_KTS"; then
  cat >> "$GRADLE_KTS" <<'KTS'

android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
KTS
elif [ -f "$GRADLE_GROOVY" ] && ! grep -q 'androidx.core:core' "$GRADLE_GROOVY"; then
  cat >> "$GRADLE_GROOVY" <<'GROOVY'

android {
    compileOptions {
        coreLibraryDesugaringEnabled true
    }
}

dependencies {
    implementation 'androidx.core:core-ktx:1.13.1'
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
GROOVY
fi

# Remove the sample test flutter create may add; this repo has its own tests.
rm -f test/widget_test.dart

echo "Platform folders are ready. Next: flutter pub get && flutter run"
