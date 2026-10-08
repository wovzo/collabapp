with open("lib/main.dart", "r") as f:
    content = f.read()

# Replace the dummy widgets in _widgetOptions
old_widgets = """  static const List<Widget> _widgetOptions = <Widget>[
    ExploreScreen(),
    Center(child: Text('My Applications')),
    Center(child: Text('Messages')),
    Center(child: Text('Profile')),
  ];"""

new_widgets = """  static const List<Widget> _widgetOptions = <Widget>[
    ExploreScreen(),
    ApplicationsScreen(),
    Center(child: Text('Messages - Coming Soon')),
    ProfileScreen(),
  ];"""

content = content.replace(old_widgets, new_widgets)

# Append the new screens at the end of the file
new_screens = """
class ApplicationsScreen extends StatelessWidget {
  const ApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'My Applications',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: Supabase.instance.client
                  .from('applications')
                  .select('*, campaigns(*, profiles(name))')
                  .eq('influencer_id', Supabase.instance.client.auth.currentUser!.id)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final apps = snapshot.data ?? [];
                
                if (apps.isEmpty) {
                  return const Center(child: Text('You haven\\'t applied to any campaigns yet.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    final campaign = app['campaigns'];
                    final brandName = campaign['profiles']['name'] ?? 'Brand';
                    
                    Color statusColor = Colors.orange;
                    if (app['status'] == 'accepted') statusColor = Colors.green;
                    if (app['status'] == 'rejected') statusColor = Colors.red;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: Text(brandName[0].toUpperCase()),
                        ),
                        title: Text(campaign['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Budget: ₹${campaign['budget']}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            app['status'].toString().toUpperCase(),
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.purple[100],
                child: const Icon(Icons.person, size: 50, color: Colors.purple),
              ),
              const SizedBox(height: 24),
              const Text(
                'Creator Profile',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                user?.email ?? 'Unknown Email',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
"""

content = content + new_screens

with open("lib/main.dart", "w") as f:
    f.write(content)

print("Added Screens")
