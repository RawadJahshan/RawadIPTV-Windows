class MovieCategory {
  final int id;
  final String name;

  MovieCategory({
    required this.id,
    required this.name,
  });

  factory MovieCategory.fromJson(Map<String, dynamic> json) {
    return MovieCategory(
      id: int.parse(json['category_id'].toString()),
      name: json['category_name'].toString(),
    );
  }
}