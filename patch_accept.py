import re

with open("lib/main.dart", "r") as f:
    content = f.read()

# Replace the text button in BrandApplicantsScreen
old_trailing = """                        trailing: app['status'] == 'pending' 
                          ? TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please use the Web App to Accept/Reject.')),
                                );
                              },
                              child: const Text('Manage'),
                            )
                          : null,"""

new_trailing = """                        trailing: app['status'] == 'pending' 
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle, color: Colors.green),
                                  onPressed: () => _updateStatus(context, app['id'], 'accepted'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  onPressed: () => _updateStatus(context, app['id'], 'rejected'),
                                ),
                              ],
                            )
                          : Icon(
                              app['status'] == 'accepted' ? Icons.check_circle : Icons.cancel,
                              color: app['status'] == 'accepted' ? Colors.green : Colors.grey,
                            ),"""

content = content.replace(old_trailing, new_trailing)

# Add _updateStatus method to BrandApplicantsScreen
# Wait, BrandApplicantsScreen is a StatelessWidget! I need to change it to StatefulWidget or pass context.
# Let's just make it a StatefulWidget.
old_class_def = """class BrandApplicantsScreen extends StatelessWidget {
  const BrandApplicantsScreen({super.key});

  @override
  Widget build(BuildContext context) {"""

new_class_def = """class BrandApplicantsScreen extends StatefulWidget {
  const BrandApplicantsScreen({super.key});

  @override
  State<BrandApplicantsScreen> createState() => _BrandApplicantsScreenState();
}

class _BrandApplicantsScreenState extends State<BrandApplicantsScreen> {
  Future<void> _updateStatus(BuildContext context, String applicationId, String newStatus) async {
    try {
      await Supabase.instance.client
          .from('applications')
          .update({'status': newStatus})
          .eq('id', applicationId);
      setState(() {}); // refresh UI
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {"""

content = content.replace(old_class_def, new_class_def)

# Fix the curly brace at the end of BrandApplicantsScreen
content = content.replace("  Future<List<Map<String, dynamic>>> _fetchApplicants() async {", "  Future<List<Map<String, dynamic>>> _fetchApplicants() async {")
# No, wait, if I changed the class to State, it ends with `}`. That works perfectly as long as I didn't mess up the regex.

with open("lib/main.dart", "w") as f:
    f.write(content)
print("Mobile Manage Patched")
