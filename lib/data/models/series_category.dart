class SeriesCategory {
  final int id;
  final String name;

  SeriesCategory({
    required this.id,
    required this.name,
  });

  factory SeriesCategory.fromJson(Map<String, dynamic> json) {
    return SeriesCategory(
      id: int.parse(json['category_id'].toString()),
      name: json['category_name'].toString(),
    );
  }
}