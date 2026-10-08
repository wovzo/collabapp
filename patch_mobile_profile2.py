import re

with open("lib/main.dart", "r") as f:
    content = f.read()

old_profile_regex = r"class ProfileScreen extends StatelessWidget \{.*?\}(?=\n\s*\n\s*class)"

new_profile = """class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() => _email = user.email ?? '');
      final data = await Supabase.instance.client.from('profiles').select('name').eq('id', user.id).maybeSingle();
      if (data != null && data['name'] != null) {
        setState(() => _nameController.text = data['name']);
      }
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        if (_nameController.text.isNotEmpty) {
          await Supabase.instance.client.from('profiles').update({'name': _nameController.text.trim()}).eq('id', user.id);
        }
        if (_passwordController.text.isNotEmpty) {
          await Supabase.instance.client.auth.updateUser(UserAttributes(password: _passwordController.text));
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Updated Successfully!')));
          _passwordController.clear();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: Color(0xFFE1BEE7),
              child: Icon(Icons.person, size: 40, color: Colors.purple),
            ),
            const SizedBox(height: 16),
            const Text('My Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_email, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 32),
            
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Profile Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password (leave blank to keep current)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Changes'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Logout', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}"""

content = re.sub(old_profile_regex, new_profile, content, flags=re.DOTALL)

with open("lib/main.dart", "w") as f:
    f.write(content)
print("Profile Patched Successfully")
