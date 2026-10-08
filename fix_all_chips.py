import re

with open("lib/main.dart", "r") as f:
    content = f.read()

bad_chip_code = """  Widget _buildSelectableChip(String label) {
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

"""

# Let's completely remove it from the file first
content = content.replace(bad_chip_code, "")

# Now let's inject it into _ExploreScreenState precisely
target = """class _ExploreScreenState extends State<ExploreScreen> {
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

"""

if target in content:
    content = content.replace(target, target + bad_chip_code)
else:
    print("WARNING: Target for ExploreScreenState not found!")

with open("lib/main.dart", "w") as f:
    f.write(content)

print("Fixed stray chips.")
