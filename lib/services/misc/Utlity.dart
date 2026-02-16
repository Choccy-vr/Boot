class Utlity {
  static String formatReadableDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0m';
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    }
    if (hours > 0) {
      return '${hours}h';
    }
    return '${minutes}m';
  }
}