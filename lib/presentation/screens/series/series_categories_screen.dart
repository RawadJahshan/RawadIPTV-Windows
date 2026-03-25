import 'package:flutter/material.dart';
import '../../../data/datasources/remote/xtream_api.dart';
import '../../../data/models/series_category.dart';
import 'series_list_screen.dart';

class SeriesCategoriesScreen extends StatefulWidget {
  final XtreamApi xtreamApi;
  const SeriesCategoriesScreen({super.key, required this.xtreamApi});

  @override
  State<SeriesCategoriesScreen> createState() =>
      _SeriesCategoriesScreenState();
}

class _SeriesCategoriesScreenState
    extends State<SeriesCategoriesScreen> {
  late Future<List<SeriesCategory>> _futureCategories;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _futureCategories = _fetchCategories();
  }

  Future<List<SeriesCategory>> _fetchCategories() async {
    final raw = await widget.xtreamApi.getSeriesCategories();
    return raw
        .map((json) => SeriesCategory.fromJson(json))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text('Series'),
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
      ),
      body: FutureBuilder<List<SeriesCategory>>(
        future: _futureCategories,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No categories found'));
          }

          final allCategories = snapshot.data!;
          final filtered = _searchQuery.isEmpty
              ? allCategories
              : allCategories
                  .where((c) => c.name
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()))
                  .toList();

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search categories...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white38,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white38,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF0F0F1A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.blue,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (value) =>
                      setState(() => _searchQuery = value),
                ),
              ),

              // Categories list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white12),
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, index) {
                    // First item is ALL
                    if (index == 0) {
                      return ListTile(
                        leading: const Icon(
                          Icons.video_library,
                          color: Color(0xFFffa69e),
                        ),
                        title: const Text(
                          'ALL Series',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white38,
                          size: 14,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SeriesListScreen(
                                xtreamApi: widget.xtreamApi,
                                category: SeriesCategory(
                                  id: -1,
                                  name: 'ALL Series',
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }

                    final category = filtered[index - 1];
                    return ListTile(
                      leading: const Icon(
                        Icons.video_library,
                        color: Color(0xFFffa69e),
                      ),
                      title: Text(
                        category.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white38,
                        size: 14,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SeriesListScreen(
                              xtreamApi: widget.xtreamApi,
                              category: category,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}