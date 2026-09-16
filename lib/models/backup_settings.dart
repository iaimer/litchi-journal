class BackupSettingsSnapshot {
  final bool enabled;
  final int weekday;
  final String time;
  final String timezone;
  final String webdavUrl;
  final String username;
  final String remotePath;
  final bool passwordConfigured;
  final int recentWeeks;
  final int monthlyMonths;
  final BackupStatus status;

  const BackupSettingsSnapshot({
    required this.enabled,
    required this.weekday,
    required this.time,
    required this.timezone,
    required this.webdavUrl,
    required this.username,
    required this.remotePath,
    required this.passwordConfigured,
    required this.recentWeeks,
    required this.monthlyMonths,
    required this.status,
  });

  factory BackupSettingsSnapshot.defaults() => BackupSettingsSnapshot(
    enabled: false,
    weekday: 0,
    time: '03:00',
    timezone: 'Asia/Shanghai',
    webdavUrl: '',
    username: '',
    remotePath: '/荔枝日记备份',
    passwordConfigured: false,
    recentWeeks: 8,
    monthlyMonths: 12,
    status: const BackupStatus(),
  );

  BackupSettingsSnapshot copyWith({
    bool? enabled,
    int? weekday,
    String? time,
    String? timezone,
    String? webdavUrl,
    String? username,
    String? remotePath,
    bool? passwordConfigured,
    int? recentWeeks,
    int? monthlyMonths,
    BackupStatus? status,
  }) {
    return BackupSettingsSnapshot(
      enabled: enabled ?? this.enabled,
      weekday: weekday ?? this.weekday,
      time: time ?? this.time,
      timezone: timezone ?? this.timezone,
      webdavUrl: webdavUrl ?? this.webdavUrl,
      username: username ?? this.username,
      remotePath: remotePath ?? this.remotePath,
      passwordConfigured: passwordConfigured ?? this.passwordConfigured,
      recentWeeks: recentWeeks ?? this.recentWeeks,
      monthlyMonths: monthlyMonths ?? this.monthlyMonths,
      status: status ?? this.status,
    );
  }

  factory BackupSettingsSnapshot.fromJson(Map<String, dynamic> json) {
    final webdav = json['webdav'];
    final retention = json['retention'];
    final rawStatus = json['status'];
    if (webdav is! Map || retention is! Map || rawStatus is! Map) {
      throw const FormatException('备份设置响应无效');
    }
    final weekday = json['weekday'];
    final time = json['time'];
    final recentWeeks = retention['recentWeeks'];
    final monthlyMonths = retention['monthlyMonths'];
    if (json['enabled'] is! bool ||
        weekday is! num ||
        weekday.toInt() != weekday ||
        weekday < 0 ||
        weekday > 6 ||
        time is! String ||
        !RegExp(r'^\d{2}:\d{2}$').hasMatch(time) ||
        webdav['url'] is! String ||
        webdav['username'] is! String ||
        webdav['remotePath'] is! String ||
        webdav['passwordConfigured'] is! bool ||
        recentWeeks is! num ||
        monthlyMonths is! num ||
        recentWeeks.toInt() != recentWeeks ||
        monthlyMonths.toInt() != monthlyMonths) {
      throw const FormatException('备份设置字段无效');
    }
    return BackupSettingsSnapshot(
      enabled: json['enabled'] as bool,
      weekday: weekday.toInt(),
      time: time,
      timezone: json['timezone'] is String
          ? json['timezone'] as String
          : 'Asia/Shanghai',
      webdavUrl: webdav['url'] as String,
      username: webdav['username'] as String,
      remotePath: webdav['remotePath'] as String,
      passwordConfigured: webdav['passwordConfigured'] as bool,
      recentWeeks: recentWeeks.toInt(),
      monthlyMonths: monthlyMonths.toInt(),
      status: BackupStatus.fromJson(Map<String, dynamic>.from(rawStatus)),
    );
  }

  Map<String, dynamic> toUpdateJson({
    String? password,
    bool clearPassword = false,
  }) {
    return {
      'enabled': enabled,
      'weekday': weekday,
      'time': time,
      'webdavUrl': webdavUrl,
      'username': username,
      'remotePath': remotePath,
      if (password != null && password.isNotEmpty) 'password': password,
      if (clearPassword) 'clearPassword': true,
    };
  }
}

enum BackupState { idle, running, success, failed }

class BackupStatus {
  final BackupState state;
  final String? phase;
  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessAt;
  final DateTime? nextRunAt;
  final String? lastFileName;
  final int? lastSizeBytes;
  final String? lastSha256;
  final String? lastError;

  const BackupStatus({
    this.state = BackupState.idle,
    this.phase,
    this.lastAttemptAt,
    this.lastSuccessAt,
    this.nextRunAt,
    this.lastFileName,
    this.lastSizeBytes,
    this.lastSha256,
    this.lastError,
  });

  factory BackupStatus.fromJson(Map<String, dynamic> json) {
    final rawState = json['state'];
    final state = switch (rawState) {
      'running' => BackupState.running,
      'success' => BackupState.success,
      'failed' => BackupState.failed,
      _ => BackupState.idle,
    };
    return BackupStatus(
      state: state,
      phase: json['phase'] as String?,
      lastAttemptAt: _parseDate(json['lastAttemptAt']),
      lastSuccessAt: _parseDate(json['lastSuccessAt']),
      nextRunAt: _parseDate(json['nextRunAt']),
      lastFileName: json['lastFileName'] as String?,
      lastSizeBytes: _wholeInt(json['lastSizeBytes']),
      lastSha256: json['lastSha256'] as String?,
      lastError: json['lastError'] as String?,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  static int? _wholeInt(Object? value) {
    if (value is! num || value < 0 || value.toInt() != value) return null;
    return value.toInt();
  }
}

const backupWeekdayNames = <String>['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
