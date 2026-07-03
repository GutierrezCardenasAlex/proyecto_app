class AppUpdateManifest {
  const AppUpdateManifest({
    required this.appId,
    required this.platform,
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    required this.mandatory,
    required this.title,
    required this.message,
    required this.notes,
    required this.updatedAt,
  });

  final String appId;
  final String platform;
  final String version;
  final int buildNumber;
  final String apkUrl;
  final bool mandatory;
  final String title;
  final String message;
  final List<String> notes;
  final String? updatedAt;

  factory AppUpdateManifest.fromJson(Map<String, dynamic> json) {
    final rawNotes = json['notes'];
    return AppUpdateManifest(
      appId: (json['appId'] ?? '').toString(),
      platform: (json['platform'] ?? 'android').toString(),
      version: (json['version'] ?? '0.0.0').toString(),
      buildNumber: int.tryParse('${json['buildNumber'] ?? json['build'] ?? 0}') ?? 0,
      apkUrl: (json['apkUrl'] ?? '').toString(),
      mandatory: json['mandatory'] == true,
      title: (json['title'] ?? 'Actualizacion disponible').toString(),
      message: (json['message'] ?? 'Hay una nueva version disponible.').toString(),
      notes: rawNotes is List ? rawNotes.map((item) => item.toString()).toList() : const [],
      updatedAt: json['updatedAt']?.toString(),
    );
  }
}
