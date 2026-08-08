class PromotionCampaignStats {
  const PromotionCampaignStats({
    required this.campaignId,
    required this.targetType,
    required this.targetId,
    required this.impressions,
    required this.clicks,
    required this.detailViews,
    required this.qualifiedConversions,
    required this.financialConversions,
    required this.attributedRevenue,
    required this.refundedRevenue,
    required this.netAttributedRevenue,
    required this.currency,
    required this.spend,
    required this.revenueCapability,
    required this.financialMetricsStatus,
    required this.reconciliationStatus,
    this.sector,
    this.pricingVersion,
    this.planId,
    this.durationHours,
    this.startsAt,
    this.expiresAt,
    this.campaignStatus,
    this.updatedAt,
    this.ctr,
    this.conversionRate,
    this.roas,
    this.lastReconciledAt,
  });

  factory PromotionCampaignStats.fromJson(Map<String, dynamic> json) {
    double? number(Object? value) => value is num ? value.toDouble() : null;
    int integer(Object? value) => value is num ? value.toInt() : 0;
    return PromotionCampaignStats(
      campaignId: json['campaignId']?.toString() ?? '',
      targetType: json['targetType']?.toString() ?? '',
      targetId: json['targetId']?.toString() ?? '',
      sector: json['sector']?.toString(),
      impressions: integer(json['impressions']),
      clicks: integer(json['clicks']),
      detailViews: integer(json['detailViews']),
      qualifiedConversions: integer(json['qualifiedConversions']),
      financialConversions: integer(json['financialConversions']),
      attributedRevenue: number(json['attributedRevenue']) ?? 0,
      refundedRevenue: number(json['refundedRevenue']) ?? 0,
      netAttributedRevenue:
          number(json['netAttributedRevenue']) ??
          (number(json['attributedRevenue']) ?? 0) -
              (number(json['refundedRevenue']) ?? 0),
      currency: json['currency']?.toString(),
      spend: number(json['spend']) ?? 0,
      pricingVersion: integer(json['pricingVersion']),
      planId: json['planId']?.toString(),
      durationHours: integer(json['durationHours']),
      startsAt: json['startsAt'],
      expiresAt: json['expiresAt'],
      campaignStatus: json['campaignStatus']?.toString(),
      revenueCapability: json['revenueCapability']?.toString() ?? 'unknown',
      financialMetricsStatus:
          json['financialMetricsStatus']?.toString() ?? 'PROVISIONAL',
      reconciliationStatus:
          json['reconciliationStatus']?.toString() ?? 'PENDING',
      updatedAt: json['updatedAt'],
      ctr: number(json['ctr']),
      conversionRate: number(json['conversionRate']),
      roas: number(json['roas']),
      lastReconciledAt: json['lastReconciledAt'],
    );
  }

  final String campaignId;
  final String targetType;
  final String targetId;
  final String? sector;
  final int impressions;
  final int clicks;
  final int detailViews;
  final int qualifiedConversions;
  final int financialConversions;
  final double attributedRevenue;
  final double refundedRevenue;
  final double netAttributedRevenue;
  final String? currency;
  final double spend;
  final int? pricingVersion;
  final String? planId;
  final int? durationHours;
  final Object? startsAt;
  final Object? expiresAt;
  final String? campaignStatus;
  final String revenueCapability;
  final String financialMetricsStatus;
  final String reconciliationStatus;
  final Object? updatedAt;
  final Object? lastReconciledAt;
  final double? ctr;
  final double? conversionRate;
  final double? roas;

  bool get hasRevenueAttribution => revenueCapability == 'server_attributed';
}
