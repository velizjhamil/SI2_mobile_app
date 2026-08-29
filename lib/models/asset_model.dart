class AssetModel {
  final String id;
  final String name;
  final String category;
  final String symbol;
  final double value;
  final double portfolioPercentage;
  final double change24h;
  final bool isPositive;
  final bool isHighlighted;
  final String description;

  const AssetModel({
    required this.id,
    required this.name,
    required this.category,
    required this.symbol,
    required this.value,
    required this.portfolioPercentage,
    required this.change24h,
    required this.isPositive,
    this.isHighlighted = false,
    required this.description,
  });
}
