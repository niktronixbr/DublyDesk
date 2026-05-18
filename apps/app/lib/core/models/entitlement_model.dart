class EntitlementModel {
  final bool pro;
  final bool trial;
  final DateTime? until;
  final String? source;
  final bool cancelAtPeriodEnd;

  const EntitlementModel({
    required this.pro,
    required this.trial,
    required this.until,
    required this.source,
    required this.cancelAtPeriodEnd,
  });

  const EntitlementModel.free()
      : pro = false,
        trial = false,
        until = null,
        source = null,
        cancelAtPeriodEnd = false;

  factory EntitlementModel.fromJson(Map<String, dynamic> json) {
    DateTime? until;
    final rawUntil = json['until'];
    if (rawUntil != null && rawUntil.toString().isNotEmpty) {
      until = DateTime.tryParse(rawUntil.toString());
    }
    return EntitlementModel(
      pro: json['pro'] == true,
      trial: json['trial'] == true,
      until: until,
      source: json['source']?.toString(),
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] == true,
    );
  }

  int? get daysUntilExpiry {
    if (until == null) return null;
    return until!.difference(DateTime.now()).inDays;
  }
}
