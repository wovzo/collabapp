with open("lib/main.dart", "r") as f:
    content = f.read()

bad_func = """  Widget _buildSelectableChip(String label) {
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
  Widget build(BuildContext context) {
    return MaterialApp("""

good_app = """  @override
  Widget build(BuildContext context) {
    return MaterialApp("""

content = content.replace(bad_func, good_app)

# Now put bad_func inside _ExploreScreenState where it belongs
target_explore = """  @override
  Widget build(BuildContext context) {
    return SafeArea("""

fixed_explore = """  Widget _buildSelectableChip(String label) {
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
  Widget build(BuildContext context) {
    return SafeArea("""

content = content.replace(target_explore, fixed_explore)

with open("lib/main.dart", "w") as f:
    f.write(content)
print("Chip fixed")
