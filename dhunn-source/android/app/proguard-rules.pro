-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio_background.** { *; }
-keep class dev.fluttercommunity.plus.** { *; }
-dontwarn com.google.android.exoplayer2.**
-keep class com.google.android.exoplayer2.** { *; }

# media3 streaming modules excluded on purpose (local playback only)
-dontwarn androidx.media3.exoplayer.dash.**
-dontwarn androidx.media3.exoplayer.hls.**
-dontwarn androidx.media3.exoplayer.smoothstreaming.**
-dontwarn androidx.media3.datasource.cronet.**
