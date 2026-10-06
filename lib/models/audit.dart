/// How one part of a business's online presence is doing.
enum AuditStatus { good, warn, bad }

/// The five rows shown on the audit graphic, in order.
enum AuditArea { maps, website, social, seo, ai }

extension AuditAreaLabel on AuditArea {
  String get label => switch (this) {
        AuditArea.maps => 'Google Maps profile',
        AuditArea.website => 'Website',
        AuditArea.social => 'Social media',
        AuditArea.seo => 'Google Search (SEO)',
        AuditArea.ai => 'AI answers (AEO · GEO)',
      };

  /// Short label for the email header card and lists.
  String get shortLabel => switch (this) {
        AuditArea.maps => 'Google Maps',
        AuditArea.website => 'Website',
        AuditArea.social => 'Social media',
        AuditArea.seo => 'SEO',
        AuditArea.ai => 'AEO · GEO',
      };
}

class AuditItem {
  const AuditItem({
    required this.area,
    required this.status,
    required this.verdict,
    required this.detail,
  });

  final AuditArea area;
  final AuditStatus status;

  /// One or two words shown in the pill, e.g. "Missing".
  final String verdict;

  /// One line explaining what was found, shown in the app only.
  final String detail;

  AuditItem copyWith({AuditStatus? status, String? verdict}) => AuditItem(
        area: area,
        status: status ?? this.status,
        verdict: verdict ?? this.verdict,
        detail: detail,
      );

  Map<String, dynamic> toJson() => {
        'area': area.name,
        'status': status.name,
        'verdict': verdict,
        'detail': detail,
      };

  factory AuditItem.fromJson(Map<String, dynamic> json) => AuditItem(
        area: AuditArea.values.firstWhere(
          (a) => a.name == json['area'],
          orElse: () => AuditArea.maps,
        ),
        status: AuditStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => AuditStatus.warn,
        ),
        verdict: (json['verdict'] as String?) ?? '',
        detail: (json['detail'] as String?) ?? '',
      );
}
