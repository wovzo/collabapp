import re

with open("lib/main.dart", "r") as f:
    content = f.read()

# Define the new Brand classes
new_brand_code = """
class BrandMainScreen extends StatefulWidget {
  const BrandMainScreen({super.key});

  @override
  State<BrandMainScreen> createState() => _BrandMainScreenState();
}

class _BrandMainScreenState extends State<BrandMainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    BrandCampaignsScreen(),
    BrandApplicantsScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'Campaigns',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Applicants',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class BrandCampaignsScreen extends StatelessWidget {
  const BrandCampaignsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Campaigns',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to web app reminder or a creation form
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please use the Web App to create new campaigns.')),
                    );
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New'),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: Supabase.instance.client
                  .from('campaigns')
                  .select('*, applications(count)')
                  .eq('brand_id', userId)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final campaigns = snapshot.data ?? [];
                if (campaigns.isEmpty) {
                  return const Center(child: Text('You have not created any campaigns yet.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: campaigns.length,
                  itemBuilder: (context, index) {
                    final campaign = campaigns[index];
                    final appsCount = campaign['applications'] != null && campaign['applications'].isNotEmpty 
                        ? campaign['applications'][0]['count'] 
                        : 0;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(campaign['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: campaign['status'] == 'active' ? Colors.green[50] : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    campaign['status'].toUpperCase(),
                                    style: TextStyle(
                                      color: campaign['status'] == 'active' ? Colors.green[700] : Colors.grey[700],
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Platform: ${campaign['platform'].toString().toUpperCase()} • Budget: ₹${campaign['budget']}', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.purple[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.people, size: 16, color: Colors.purple),
                                  const SizedBox(width: 8),
                                  Text('$appsCount Applicants', style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
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

class BrandApplicantsScreen extends StatelessWidget {
  const BrandApplicantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Influencer Applications',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchApplicants(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final apps = snapshot.data ?? [];
                if (apps.isEmpty) {
                  return const Center(child: Text('No applications yet.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    final profile = app['profiles'];
                    final campaign = app['campaigns'];
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple[100],
                          child: Text(profile['name']?[0]?.toUpperCase() ?? 'I', style: const TextStyle(color: Colors.purple)),
                        ),
                        title: Text(profile['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Applied for: ${campaign['title']}\\nStatus: ${app['status'].toUpperCase()}'),
                        isThreeLine: true,
                        trailing: app['status'] == 'pending' 
                          ? TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please use the Web App to Accept/Reject.')),
                                );
                              },
                              child: const Text('Manage'),
                            )
                          : null,
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

  Future<List<Map<String, dynamic>>> _fetchApplicants() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];
    
    // Fetch all applications
    final appsResponse = await Supabase.instance.client
        .from('applications')
        .select('*, profiles:influencer_id(name), campaigns:campaign_id(title, brand_id)')
        .order('created_at', ascending: false);
        
    // Filter locally to avoid complex joins in Flutter for now
    return appsResponse.where((app) => app['campaigns']['brand_id'] == userId).toList();
  }
}
"""

# Extract everything before BrandMainScreen
pattern = r"(class BrandMainScreen extends StatelessWidget \{.*?)class ApplicationsScreen extends StatelessWidget \{"
# We need DOTALL to match across newlines
match = re.search(pattern, content, re.DOTALL)

if match:
    old_brand_code = match.group(1)
    content = content.replace(old_brand_code, new_brand_code + "\n\n")
    with open("lib/main.dart", "w") as f:
        f.write(content)
    print("Brand UI Built successfully!")
else:
    print("Could not find BrandMainScreen")

