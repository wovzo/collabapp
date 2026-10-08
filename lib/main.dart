import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://rbnbyodbwcpvpfepfnuk.supabase.co',
    anonKey: 'sb_publishable_VwyOn1NVlLb-gJSUwVzNfA_KHOTRkUs',
  );
  
  runApp(const WovzoCollabApp());
}

class WovzoCollabApp extends StatelessWidget {
  const WovzoCollabApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wovzo Collab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  late final StreamSubscription<AuthState> _authSubscription;
  
  bool _isLogin = true;
  bool _isLoading = false;
  String _selectedRole = 'influencer';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.passwordRecovery && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const UpdatePasswordScreen()),
        );
      }
    });
  }



  Future<void> _submitAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        // LOGIN
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (response.user != null) {
          var profile = await Supabase.instance.client
              .from('profiles')
              .select('role')
              .eq('id', response.user!.id)
              .maybeSingle();
              
          // If profile is missing (e.g. created manually in dashboard without trigger), create it now
          if (profile == null) {
             await Supabase.instance.client.from('profiles').insert({
               'id': response.user!.id,
               'name': 'User',
               'role': _selectedRole
             });
             profile = {'role': _selectedRole};
          }

          if (profile!['role'] != _selectedRole) {
            await Supabase.instance.client.auth.signOut();
            setState(() {
              _errorMessage = 'Incorrect role selected. This email is registered as a ${profile!['role']}.';
            });
            return;
          }

          if (mounted) {
            if (profile['role'] == 'brand') {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const BrandMainScreen()),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const InfluencerMainScreen()),
              );
            }
          }
          return;
        }
      } else {
        // SIGNUP
        final response = await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {
            'name': _nameController.text.trim(),
            'role': _selectedRole,
          },
        );
        
        if (mounted && response.user != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => _selectedRole == 'brand' 
                ? const BrandMainScreen() 
                : const InfluencerMainScreen(),
            ),
          );
        }
        return;
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address first.';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent! Check your inbox.')),
        );
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'W',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _isLogin ? 'Welcome Back' : 'Create Account',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin ? 'Sign in to find your next collaboration' : 'Sign up to apply for campaigns',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red[800], fontSize: 14),
                  ),
                ),

              SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'influencer', label: Text('Influencer')),
                    ButtonSegment(value: 'brand', label: Text('Brand')),
                  ],
                  selected: {_selectedRole},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _selectedRole = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
              if (!_isLogin) ...[
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    child: const Text('Forgot Password?'),
                  ),
                )
              else
                const SizedBox(height: 16),
              if (_isLogin) const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitAuth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading 
                    ? const SizedBox(
                        height: 20, width: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : Text(
                        _isLogin ? 'Sign In' : 'Sign Up',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin ? 'Don\'t have an account?' : 'Already have an account?', 
                    style: TextStyle(color: Colors.grey[600])
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _errorMessage = null;
                      });
                    },
                    child: Text(_isLogin ? 'Sign Up' : 'Sign In'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class InfluencerMainScreen extends StatefulWidget {
  const InfluencerMainScreen({super.key});

  @override
  State<InfluencerMainScreen> createState() => _InfluencerMainScreenState();
}

class _InfluencerMainScreenState extends State<InfluencerMainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    ExploreScreen(),
    ApplicationsScreen(),
    MessagesScreen(isBrand: false),
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
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Applications',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
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

class ExploreScreen extends StatefulWidget {
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
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          // Add dummy delay just to show refresh spinner
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hey there! 👋',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Find your next collaboration',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: const Text('I'),
                )
              ],
            ),
            const SizedBox(height: 24),
            
            // Search Bar
            TextField(
              onChanged: _updateSearch,
              decoration: InputDecoration(
                hintText: 'Search brands, categories...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Categories
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
            ),
            const SizedBox(height: 24),
            
            Text(
              'Top Campaigns',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
            const SizedBox(height: 16),
            
            // Dynamic Campaign Cards from Supabase
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
              }(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                
                final campaigns = snapshot.data ?? [];
                
                if (campaigns.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(
                      child: Text('No campaigns available yet.'),
                    ),
                  );
                }

                return Column(
                  children: campaigns.map((campaign) {
                    final profile = campaign['profiles'] as Map<String, dynamic>?;
                    final brandName = profile != null ? profile['name'] : 'Unknown Brand';
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: _buildCampaignCard(
                        context: context,
                        brandName: brandName.toString(),
                        campaignTitle: campaign['title'].toString(),
                        budget: '₹${campaign['budget']}',
                        requirements: campaign['requirements'].toString(),
                        color: Colors.blue, // Can be randomized later
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignCard({
    required BuildContext context,
    required String brandName,
    required String campaignTitle,
    required String budget,
    required String requirements,
    required Color color,
    String? campaignId,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    brandName.isNotEmpty ? brandName[0].toUpperCase() : "B",
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brandName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      campaignTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  budget,
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.check_circle_outline, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                requirements,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
                        child: ElevatedButton(
              onPressed: () async {
                if (campaignId == null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CampaignDetailsScreen(
                        brandName: brandName,
                        campaignTitle: campaignTitle,
                        budget: budget,
                        requirements: requirements,
                        color: color,
                      ),
                    ),
                  );
                  return;
                }
                
                try {
                  final userId = Supabase.instance.client.auth.currentUser?.id;
                  if (userId == null) return;
                  
                  await Supabase.instance.client.from("applications").insert({
                    "campaign_id": campaignId,
                    "influencer_id": userId,
                  });
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Successfully applied to campaign!")),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("You have already applied or an error occurred.")),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[50],
                foregroundColor: Colors.blue[700],
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('View Details'),
            ),
          ),
        ],
      ),
    );
  }
}

class CampaignDetailsScreen extends StatelessWidget {
  final String brandName;
  final String campaignTitle;
  final String budget;
  final String requirements;
  final Color color;

  const CampaignDetailsScreen({
    super.key,
    required this.brandName,
    required this.campaignTitle,
    required this.budget,
    required this.requirements,
    required this.color,
  });


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Campaign Details', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    brandName.isNotEmpty ? brandName[0].toUpperCase() : "B",
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                brandName,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                campaignTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard('Budget', budget, Icons.account_balance_wallet_outlined, Colors.green),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoCard('Platform', 'Instagram', Icons.camera_alt_outlined, Colors.purple),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'About the Campaign',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'We are looking for energetic creators to promote our new product launch. You will be provided with the product and a creative brief. We want authentic, engaging content that highlights the core features.',
              style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.5),
            ),
            const SizedBox(height: 32),
            const Text(
              'Requirements & Deliverables',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildRequirementItem('Minimum Followers', requirements.split('•')[0].trim()),
            _buildRequirementItem('Deliverables', requirements.split('•').length > 1 ? requirements.split('•')[1].trim() : 'Content creation'),
            _buildRequirementItem('Usage Rights', '6 months digital ads'),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Apply Now',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.blue[400], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(value, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


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
    MessagesScreen(isBrand: true),
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
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
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
                  onPressed: () async {
                    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateCampaignScreen()));
                    if (result == true) {
                      // refresh
                      (context as Element).markNeedsBuild();
                    }
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
                  .eq('brand_id', userId ?? '')
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

class BrandApplicantsScreen extends StatefulWidget {
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
                        subtitle: Text('Applied for: ${campaign['title']}\nStatus: ${app['status'].toUpperCase()}'),
                        isThreeLine: true,
                        trailing: app['status'] == 'pending' 
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
                  return const Center(child: Text('You haven\'t applied to any campaigns yet.'));
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

class ProfileScreen extends StatefulWidget {
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
}

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});
  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _updatePassword() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text.trim()),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully!')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _updatePassword,
              child: const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }
}

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

class MessagesScreen extends StatefulWidget {
  final bool isBrand;
  const MessagesScreen({super.key, required this.isBrand});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final targetRole = widget.isBrand ? 'influencer' : 'brand';
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, name')
          .eq('role', targetRole);
      
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Messages', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? const Center(child: Text('No users found to chat.'))
                    : ListView.builder(
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final u = _users[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue[100],
                              child: Text(u['name']?[0]?.toUpperCase() ?? 'U', style: const TextStyle(color: Colors.blue)),
                            ),
                            title: Text(u['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(peerId: u['id'], peerName: u['name'] ?? 'Unknown')));
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

class ChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  const ChatScreen({super.key, required this.peerId, required this.peerName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  late final RealtimeChannel _channel;
  String _myId = '';

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser!.id;
    _fetchMessages();
    _setupSubscription();
  }

  Future<void> _fetchMessages() async {
    final response = await Supabase.instance.client
        .from('messages')
        .select('*')
        .or('and(sender_id.eq.$_myId,receiver_id.eq.${widget.peerId}),and(sender_id.eq.${widget.peerId},receiver_id.eq.$_myId)')
        .order('created_at', ascending: true);
    
    if (mounted) {
      setState(() {
        _messages = List<Map<String, dynamic>>.from(response);
      });
    }
  }

  void _setupSubscription() {
    _channel = Supabase.instance.client
        .channel('public:messages')
        .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              final msg = payload.newRecord;
              if ((msg['sender_id'] == _myId && msg['receiver_id'] == widget.peerId) ||
                  (msg['sender_id'] == widget.peerId && msg['receiver_id'] == _myId)) {
                if (mounted) {
                  setState(() {
                    _messages.add(msg);
                  });
                }
              }
            })
        .subscribe();
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_channel);
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;
    final text = _msgController.text.trim();
    _msgController.clear();
    
    await Supabase.instance.client.from('messages').insert({
      'sender_id': _myId,
      'receiver_id': widget.peerId,
      'content': text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.peerName)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender_id'] == _myId;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      msg['content'],
                      style: TextStyle(color: isMe ? Colors.white : Colors.black),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
