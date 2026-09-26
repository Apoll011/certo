import '../models/medication.dart';

/// Status of a caregiver↔patient consent link.
enum CaregiverLinkStatus { pending, active, revoked }

CaregiverLinkStatus caregiverLinkStatusFromString(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'active':
      return CaregiverLinkStatus.active;
    case 'revoked':
      return CaregiverLinkStatus.revoked;
    default:
      return CaregiverLinkStatus.pending;
  }
}

extension CaregiverLinkStatusX on CaregiverLinkStatus {
  String get apiValue => name;
}

/// A consent link between a caregiver and a patient.
class CaregiverLink {
  const CaregiverLink({
    required this.id,
    required this.patientId,
    required this.inviteCode,
    required this.status,
    this.caregiverId,
    this.label = '',
    this.patientName = '',
    this.caregiverName = '',
    this.createdAt,
    this.consentedAt,
    this.revokedAt,
  });

  final String id;
  final String patientId;
  final String? caregiverId;
  final String inviteCode;
  final CaregiverLinkStatus status;

  /// Caregiver-facing nickname for the patient.
  final String label;
  final String patientName;
  final String caregiverName;
  final DateTime? createdAt;
  final DateTime? consentedAt;
  final DateTime? revokedAt;

  String get displayName {
    if (label.trim().isNotEmpty) return label.trim();
    if (patientName.trim().isNotEmpty) return patientName.trim();
    return 'Patient';
  }

  factory CaregiverLink.fromJson(Map<String, dynamic> json) {
    return CaregiverLink(
      id: json['id']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? '',
      caregiverId: json['caregiver_id']?.toString(),
      inviteCode: json['invite_code']?.toString() ?? '',
      status: caregiverLinkStatusFromString(json['status']?.toString()),
      label: json['label']?.toString() ?? '',
      patientName: json['patient_name']?.toString() ??
          json['patient_name_join']?.toString() ??
          '',
      caregiverName: json['caregiver_name']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      consentedAt: DateTime.tryParse(json['consented_at']?.toString() ?? ''),
      revokedAt: DateTime.tryParse(json['revoked_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patient_id': patientId,
        if (caregiverId != null) 'caregiver_id': caregiverId,
        'invite_code': inviteCode,
        'status': status.apiValue,
        'label': label,
        'patient_name': patientName,
        'caregiver_name': caregiverName,
      };

  CaregiverLink copyWith({
    String? label,
    CaregiverLinkStatus? status,
    String? caregiverId,
    String? patientName,
    DateTime? consentedAt,
    DateTime? revokedAt,
  }) {
    return CaregiverLink(
      id: id,
      patientId: patientId,
      caregiverId: caregiverId ?? this.caregiverId,
      inviteCode: inviteCode,
      status: status ?? this.status,
      label: label ?? this.label,
      patientName: patientName ?? this.patientName,
      caregiverName: caregiverName,
      createdAt: createdAt,
      consentedAt: consentedAt ?? this.consentedAt,
      revokedAt: revokedAt ?? this.revokedAt,
    );
  }
}

/// Per-day adherence color for the caregiver heatmap.
enum AdherenceDayTone { none, good, uncertain, alert }

/// One day cell in the calendar heatmap.
class AdherenceDay {
  const AdherenceDay({
    required this.date,
    required this.tone,
    this.takenCount = 0,
    this.scheduledCount = 0,
    this.uncertainCount = 0,
    this.mismatchCount = 0,
    this.missedCount = 0,
  });

  final DateTime date;
  final AdherenceDayTone tone;
  final int takenCount;
  final int scheduledCount;
  final int uncertainCount;
  final int mismatchCount;
  final int missedCount;

  String get summary {
    switch (tone) {
      case AdherenceDayTone.good:
        return 'All doses confirmed';
      case AdherenceDayTone.uncertain:
        return 'Something was uncertain';
      case AdherenceDayTone.alert:
        return 'Missed or mismatched dose';
      case AdherenceDayTone.none:
        return 'No data';
    }
  }
}

/// Snapshot a caregiver sees for one person they support.
class CareRecipientSnapshot {
  const CareRecipientSnapshot({
    required this.link,
    required this.medications,
    required this.heatmap,
    required this.takenTodayIds,
    this.todayTone = AdherenceDayTone.none,
  });

  final CaregiverLink link;
  final List<Medication> medications;
  final List<AdherenceDay> heatmap;
  final Set<String> takenTodayIds;
  final AdherenceDayTone todayTone;

  int get activeMedCount =>
      medications.where((m) => m.status == MedicationStatus.active).length;
}
