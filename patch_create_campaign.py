import re

with open("lib/main.dart", "r") as f:
    content = f.read()

create_screen = """
class CreateCampaignScreen extends StatefulWidget {
  const CreateCampaignScreen({super.key});
  @override
  State<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends State<CreateCampaignScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _platformController = TextEditingController();
  final _budgetController = TextEditingController();
  final _nicheController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (_titleController.text.isEmpty || _descController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('campaigns').insert({
        'brand_id': userId,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'platform': _platformController.text.trim().isEmpty ? 'instagram' : _platformController.text.trim(),
        'budget': int.tryParse(_budgetController.text) ?? 0,
        'niche': _nicheController.text.trim(),
        'status': 'active'
      });
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campaign Created Successfully!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Campaign')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _descController, maxLines: 3, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _platformController, decoration: const InputDecoration(labelText: 'Platform (e.g. instagram)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _budgetController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Budget (₹)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _nicheController, decoration: const InputDecoration(labelText: 'Niche/Category (e.g. Fashion)', border: OutlineInputBorder())),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Create Campaign'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
"""

content = content + create_screen

# Replace the + New button action in BrandCampaignsScreen
old_btn = """                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to web app reminder or a creation form
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please use the Web App to create new campaigns.')),
                    );
                  },"""

new_btn = """                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateCampaignScreen()));
                    if (result == true) {
                      // refresh
                      (context as Element).markNeedsBuild();
                    }
                  },"""

content = content.replace(old_btn, new_btn)

with open("lib/main.dart", "w") as f:
    f.write(content)
print("Create Campaign added to Mobile")
