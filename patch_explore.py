with open("lib/main.dart", "r") as f:
    content = f.read()

# Replace ExploreScreen class definition
old_explore = """class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {"""

new_explore = """class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'For You';

  void _updateSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _updateCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  @override
  Widget build(BuildContext context) {"""
content = content.replace(old_explore, new_explore)

# Update TextField to use onChanged
old_textfield = """            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search brands, categories...',"""
new_textfield = """            // Search Bar
            TextField(
              onChanged: _updateSearch,
              decoration: InputDecoration(
                hintText: 'Search brands, categories...',"""
content = content.replace(old_textfield, new_textfield)

# Update Category chips logic
old_chips = """            // Categories
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildCategoryChip('For You', true),
                  _buildCategoryChip('Fashion', false),
                  _buildCategoryChip('Tech', false),
                  _buildCategoryChip('Fitness', false),
                  _buildCategoryChip('Food', false),
                ],
              ),
            ),"""

new_chips = """            // Categories
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildSelectableChip('For You'),
                  _buildSelectableChip('Fashion'),
                  _buildSelectableChip('Tech'),
                  _buildSelectableChip('Fitness'),
                  _buildSelectableChip('Food'),
                ],
              ),
            ),"""
content = content.replace(old_chips, new_chips)


# We need to add the _buildSelectableChip function inside _ExploreScreenState
# Let's find _buildCategoryChip which is currently outside somewhere? No, it's probably a standalone function or inside the class. Let's just define _buildSelectableChip before `Widget build`
chip_func = """
  Widget _buildSelectableChip(String label) {
    final isSelected = _selectedCategory == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool selected) {
          if (selected) _updateCategory(label);
        },
        selectedColor: Colors.blue[600],
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: Colors.grey[100],
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  @override
"""
content = content.replace("  @override\n  Widget build(BuildContext context) {", chip_func + "  Widget build(BuildContext context) {")


# Update the Supabase Query inside FutureBuilder
# old query:
#              future: Supabase.instance.client
#                  .from('campaigns')
#                  .select('*, profiles(name)')
#                  .eq('status', 'active')
#                  .order('created_at', ascending: false),
#
# new query:
#              future: Supabase.instance.client
#                  .from('campaigns')
#                  .select('*, profiles(name)')
#                  .eq('status', 'active')
#                  .order('created_at', ascending: false),

query_old = """            // Dynamic Campaign Cards from Supabase
            FutureBuilder<List<Map<String, dynamic>>>(
              future: Supabase.instance.client
                  .from('campaigns')
                  .select('*, profiles(name)')
                  .eq('status', 'active')
                  .order('created_at', ascending: false),"""

query_new = """            // Dynamic Campaign Cards from Supabase
            FutureBuilder<List<Map<String, dynamic>>>(
              future: () {
                var query = Supabase.instance.client
                    .from('campaigns')
                    .select('*, profiles(name)')
                    .eq('status', 'active');
                
                if (_selectedCategory != 'For You') {
                  // Assuming category matching on niche or title for now since we don't have a category column yet
                  query = query.ilike('niche', '%$_selectedCategory%');
                }
                
                if (_searchQuery.isNotEmpty) {
                  query = query.ilike('title', '%$_searchQuery%');
                }
                
                return query.order('created_at', ascending: false);
              }(),"""
content = content.replace(query_old, query_new)

with open("lib/main.dart", "w") as f:
    f.write(content)

print("Explore Screen Patched!")
