# Cannon Craze ships with minification disabled (the game is small and
# Processing relies on reflection in places). If you enable minifyEnabled,
# keep the Processing runtime intact:
-keep class processing.** { *; }
-dontwarn processing.**
