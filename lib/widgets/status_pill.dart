import 'package:flutter/material.dart';

import '../models/audit.dart';
import '../theme.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.status,
    required this.text,
    this.fontSize = 13,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  final AuditStatus status;
  final String text;
  final double fontSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Brand.pillBg(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          fontFamily: Brand.body,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          color: Brand.pillFg(status),
        ),
      ),
    );
  }
}

IconData areaIcon(AuditArea area) => switch (area) {
      AuditArea.maps => Icons.place_outlined,
      AuditArea.website => Icons.language,
      AuditArea.social => Icons.forum_outlined,
      AuditArea.seo => Icons.search,
      AuditArea.ai => Icons.auto_awesome_outlined,
    };
