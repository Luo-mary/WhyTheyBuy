/// Model for investor card display on home page
class InvestorCardModel {
  final String id;
  final String name;
  final String investorType;
  final String? disclosureType;
  final int? transparencyScore;
  final String? logoUrl;
  final String? lastUpdate;
  final int? totalHoldings;
  final int? changesLast30Days;
  final String? description;
  final bool isFeatured;

  const InvestorCardModel({
    required this.id,
    required this.name,
    required this.investorType,
    this.disclosureType,
    this.transparencyScore,
    this.logoUrl,
    this.lastUpdate,
    this.totalHoldings,
    this.changesLast30Days,
    this.description,
    this.isFeatured = false,
  });

  factory InvestorCardModel.fromJson(Map<String, dynamic> json) {
    return InvestorCardModel(
      id: json['id'] as String,
      name: json['name'] as String,
      investorType: json['investor_type'] as String? ?? 'Unknown',
      disclosureType: json['disclosure_type'] as String?,
      transparencyScore: json['transparency_score'] as int?,
      logoUrl: json['logo_url'] as String?,
      lastUpdate: json['last_update'] as String?,
      totalHoldings: json['total_holdings'] as int?,
      changesLast30Days: json['changes_last_30_days'] as int?,
      description: json['description'] as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'investor_type': investorType,
      'disclosure_type': disclosureType,
      'transparency_score': transparencyScore,
      'logo_url': logoUrl,
      'last_update': lastUpdate,
      'total_holdings': totalHoldings,
      'changes_last_30_days': changesLast30Days,
      'description': description,
      'is_featured': isFeatured,
    };
  }

  /// Get investor type display name
  String get investorTypeDisplay {
    switch (investorType.toLowerCase()) {
      case 'etf_manager':
        return 'ETF Manager';
      case 'hedge_fund':
        return 'Hedge Fund';
      case 'institutional':
        return 'Institutional';
      case 'individual':
        return 'Individual';
      case 'insider':
        return 'Insider';
      default:
        return investorType;
    }
  }

  /// Get disclosure type display
  String get disclosureTypeDisplay {
    switch (disclosureType?.toLowerCase()) {
      case 'etf_holdings':
        return 'Daily ETF';
      case 'sec_13f':
        return 'SEC 13F';
      case 'n_port':
        return 'N-PORT';
      case 'form_4':
        return 'Form 4';
      default:
        return disclosureType ?? 'Unknown';
    }
  }
}
