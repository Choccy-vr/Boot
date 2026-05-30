class BootEvents {
  // June 1st 2026 11:59PM EST (EDT)
  static final DateTime bootDevlogEnd = DateTime.parse(
    "2026-06-01T23:59:00-04:00",
  ).toUtc();

  // June 8th 2026 11:59 PM EST (EDT)
  static final DateTime bootFullyLocked = DateTime.parse(
    "2026-06-08T23:59:00-04:00",
  ).toUtc();

  static bool get isBootEnded {
    return DateTime.now().toUtc().isAfter(bootDevlogEnd);
  }

  static bool get isFullyLocked {
    return DateTime.now().toUtc().isAfter(bootFullyLocked);
  }
}
