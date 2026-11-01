import '../models/lead.dart';
import 'server.dart';

enum Period {
  day('Day'),
  week('Week'),
  month('Month');

  const Period(this.label);
  final String label;
}

class WorkCounts {
  const WorkCounts({this.leads = 0, this.sent = 0, this.replies = 0, this.won = 0, this.searches = 0});
  final int leads;
  final int sent;
  final int replies;
  final int won;
  final int searches;

  factory WorkCounts.fromJson(Map? j) {
    int n(String k) => (j?[k] as num?)?.toInt() ?? 0;
    return WorkCounts(leads: n('leads'), sent: n('sent'), replies: n('replies'), won: n('won'), searches: n('searches'));
  }
}

class ChartBar {
  const ChartBar(this.label, this.leads, this.sent);
  final String label;
  final int leads;
  final int sent;

  factory ChartBar.fromJson(Map j) =>
      ChartBar('${j['label']}', (j['leads'] as num?)?.toInt() ?? 0, (j['sent'] as num?)?.toInt() ?? 0);
}

class TeamMember {
  const TeamMember({
    required this.id,
    required this.name,
    required this.initials,
    required this.email,
    required this.isTeam,
    this.siteAdmin = false,
    required this.disabled,
    required this.lastActive,
    required this.counts,
  });

  final int id;
  final String name;
  final String initials;
  final String email;

  /// false = manager or site admin.
  final bool isTeam;

  /// WordPress site administrator: always an admin, password set in WordPress.
  final bool siteAdmin;
  final bool disabled;
  final DateTime? lastActive;
  final WorkCounts counts;

  factory TeamMember.fromJson(Map j) => TeamMember(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: '${j['name'] ?? ''}',
        initials: '${j['initials'] ?? ''}',
        email: '${j['email'] ?? ''}',
        isTeam: j['role'] == 'team',
        siteAdmin: j['siteAdmin'] == true,
        disabled: j['disabled'] == true,
        lastActive: j['lastActive'] == null ? null : DateTime.tryParse('${j['lastActive']}')?.toLocal(),
        counts: WorkCounts.fromJson(j),
      );
}

class TeamReport {
  const TeamReport({
    required this.period,
    required this.totals,
    required this.previous,
    required this.bars,
    required this.team,
    required this.dailyTarget,
  });

  final Period period;
  final WorkCounts totals;
  final WorkCounts previous;
  final List<ChartBar> bars;
  final List<TeamMember> team;
  final int dailyTarget;
}

class Activity {
  const Activity({required this.type, required this.name, required this.meta, required this.at});
  final String type;
  final String name;
  final String meta;
  final DateTime? at;

  String get title => switch (type) {
        'search' => 'Searched "$name"',
        'audit' => 'Checked $name',
        'whatsapp' => 'Sent WhatsApp to $name',
        'email' => 'Emailed $name',
        'status' => '$name: ${statusLabel(meta)}',
        'followup' => 'Set a follow-up for $name',
        'client' => '$name became a client',
        _ => name,
      };

  /// Extra line, e.g. the number of search results.
  String get detail {
    if (type == 'search') {
      final more = meta.startsWith('more:');
      final n = more ? meta.substring(5) : meta;
      return more ? '$n more results' : '$n results';
    }
    return '';
  }

  static String statusLabel(String s) {
    for (final v in LeadStatus.values) {
      if (v.name == s) return v.label;
    }
    return s;
  }
}

class WorkerReport {
  const WorkerReport({required this.member, required this.since, required this.bars, required this.recent});
  final TeamMember member;
  final DateTime? since;
  final List<ChartBar> bars;
  final List<Activity> recent;
}

class RemoteLead {
  const RemoteLead({
    required this.placeId,
    required this.name,
    required this.category,
    required this.city,
    required this.status,
    required this.ownerName,
    required this.ownerId,
    required this.updatedAt,
    required this.lead,
  });

  final String placeId;
  final String name;
  final String category;
  final String city;
  final LeadStatus status;
  final String ownerName;
  final int ownerId;
  final DateTime? updatedAt;

  /// The full lead as the team member saved it (may be null).
  final Lead? lead;
}

/// Admin-only calls: reports and team accounts.
class AdminApi {
  AdminApi(this._api);
  final ApiClient _api;

  Future<TeamReport> report(Period period) async {
    final j = Map<String, dynamic>.from(await _api.get('/admin/report', query: {'period': period.name}) as Map);
    return TeamReport(
      period: period,
      totals: WorkCounts.fromJson(j['totals'] as Map?),
      previous: WorkCounts.fromJson(j['previous'] as Map?),
      bars: (j['bars'] as List? ?? const []).whereType<Map>().map(ChartBar.fromJson).toList(),
      team: (j['team'] as List? ?? const []).whereType<Map>().map(TeamMember.fromJson).toList(),
      dailyTarget: (j['dailyTarget'] as num?)?.toInt() ?? 20,
    );
  }

  Future<WorkerReport> worker(int id, Period period) async {
    final j = Map<String, dynamic>.from(await _api.get('/admin/workers/$id', query: {'period': period.name}) as Map);
    return WorkerReport(
      member: TeamMember.fromJson(j['member'] as Map),
      since: j['since'] == null ? null : DateTime.tryParse('${j['since']}')?.toLocal(),
      bars: (j['bars'] as List? ?? const []).whereType<Map>().map(ChartBar.fromJson).toList(),
      recent: (j['recent'] as List? ?? const [])
          .whereType<Map>()
          .map((a) => Activity(
                type: '${a['type']}',
                name: '${a['name'] ?? ''}',
                meta: '${a['meta'] ?? ''}',
                at: DateTime.tryParse('${a['at']}')?.toLocal(),
              ))
          .toList(),
    );
  }

  /// Everyone with today's numbers.
  Future<List<TeamMember>> team() async {
    final j = await _api.get('/admin/team') as Map;
    return (j['today'] as List? ?? const []).whereType<Map>().map(TeamMember.fromJson).toList();
  }

  /// [admin] gives reports and team management. [existing] in the reply
  /// means the email already had an account and keeps its own password.
  Future<({TeamMember member, bool existing})> addMember({
    required String name,
    required String email,
    required String password,
    bool admin = false,
  }) async {
    final j = await _api.post('/admin/team', {
      'name': name,
      'email': email,
      'password': password,
      'access': admin ? 'admin' : 'team',
    }) as Map;
    return (member: TeamMember.fromJson(j['member'] as Map), existing: j['existing'] == true);
  }

  Future<TeamMember> updateMember(int id, {bool? disabled, String? password, String? name, bool? admin}) async {
    final j = await _api.post('/admin/team/$id', {
      if (admin != null) 'access': admin ? 'admin' : 'team',
      if (disabled != null) 'disabled': disabled,
      if (password != null) 'password': password,
      if (name != null) 'name': name,
    }) as Map;
    return TeamMember.fromJson(j['member'] as Map);
  }

  Future<List<RemoteLead>> leads({int? user, String? status}) async {
    final out = <RemoteLead>[];
    for (var page = 1; page <= 10; page++) {
      final j = await _api.get('/leads', query: {
        'page': '$page',
        if (user != null) 'user': '$user',
        if (status != null) 'status': status,
      }) as Map;
      final items = (j['items'] as List? ?? const []).whereType<Map>().toList();
      for (final it in items) {
        Lead? lead;
        try {
          if (it['data'] is Map) lead = Lead.fromJson(Map<String, dynamic>.from(it['data'] as Map));
        } catch (_) {}
        final owner = (it['owner'] as Map?) ?? const {};
        out.add(RemoteLead(
          placeId: '${it['placeId']}',
          name: '${it['name'] ?? ''}',
          category: '${it['category'] ?? ''}',
          city: '${it['city'] ?? ''}',
          status: LeadStatus.values.firstWhere((s) => s.name == it['status'], orElse: () => LeadStatus.newLead),
          ownerName: '${owner['name'] ?? ''}',
          ownerId: (owner['id'] as num?)?.toInt() ?? 0,
          updatedAt: DateTime.tryParse('${it['updatedAt']}')?.toLocal(),
          lead: lead,
        ));
      }
      if (items.length < 200) break;
    }
    return out;
  }
}
