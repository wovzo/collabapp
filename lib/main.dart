import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

ImageProvider? _getAvatarImageProvider(String url) {
  if (url.isEmpty) return null;
  if (url.startsWith('data:image/')) {
    final commaIndex = url.indexOf(',');
    final base64Str = commaIndex != -1 ? url.substring(commaIndex + 1) : url;
    try {
      return MemoryImage(base64Decode(base64Str));
    } catch (e) {
      debugPrint('Failed to decode base64 avatar: $e');
      return null;
    }
  }
  return NetworkImage(url);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://rbnbyodbwcpvpfepfnuk.supabase.co',
    anonKey: 'sb_publishable_VwyOn1NVlLb-gJSUwVzNfA_KHOTRkUs',
  );
  
  runApp(const WovzoCollabApp());
}

class WovzoColors {
  static const Color orange = Color(0xFFFF6A00);
  static const Color orangeDark = Color(0xFFE55A00);
  static const Color orangeLight = Color(0xFFFFF2EB);
  static const Color black = Color(0xFF111827);
  static const Color deepBlack = Color(0xFF000000);
  static const Color charcoal = Color(0xFF1F2937);
  static const Color greyLight = Color(0xFFF8FAFC);
}

class WovzoLogo extends StatelessWidget {
  final double? height;
  final double fontSize;
  final bool showBadge;
  final bool isDark;

  const WovzoLogo({
    super.key,
    this.height,
    this.fontSize = 32,
    this.showBadge = false,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final logoHeight = height ?? (fontSize * 1.2);
    return Image.asset(
      isDark ? 'assets/images/wovzo_logo_white.png' : 'assets/images/wovzo_logo.png',
      height: logoHeight,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'WOV',
                style: TextStyle(
                  color: isDark ? Colors.white : WovzoColors.deepBlack,
                  fontWeight: FontWeight.w900,
                  fontSize: fontSize,
                  letterSpacing: -1.0,
                  fontFamily: 'Roboto',
                ),
              ),
              TextSpan(
                text: 'ZO',
                style: TextStyle(
                  color: WovzoColors.orange,
                  fontWeight: FontWeight.w900,
                  fontSize: fontSize,
                  letterSpacing: -1.0,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class WovzoCollabApp extends StatelessWidget {
  const WovzoCollabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wovzo Collab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: WovzoColors.orange,
          primary: WovzoColors.orange,
          secondary: WovzoColors.deepBlack,
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        fontFamily: 'Roboto',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: WovzoColors.orange,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          indicatorColor: WovzoColors.orangeLight,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: WovzoColors.orange);
            }
            return const IconThemeData(color: Color(0xFF64748B));
          }),
        ),
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
              const Center(
                child: WovzoLogo(height: 50),
              ),
              const SizedBox(height: 32),
              Text(
                _isLogin ? 'Welcome Back' : 'Create Account',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: WovzoColors.deepBlack),
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
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red[800], fontSize: 14),
                  ),
                ),

              SegmentedButton<String>(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return WovzoColors.orangeLight;
                      }
                      return null;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return WovzoColors.orange;
                      }
                      return WovzoColors.deepBlack;
                    }),
                    side: WidgetStateProperty.all(const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  segments: const [
                    ButtonSegment(value: 'influencer', label: Text('Influencer', style: TextStyle(fontWeight: FontWeight.w600))),
                    ButtonSegment(value: 'brand', label: Text('Brand', style: TextStyle(fontWeight: FontWeight.w600))),
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
                    style: TextButton.styleFrom(foregroundColor: WovzoColors.orange),
                    child: const Text('Forgot Password?'),
                  ),
                )
              else
                const SizedBox(height: 16),
              if (_isLogin) const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitAuth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: WovzoColors.orange,
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
                    style: TextButton.styleFrom(
                      foregroundColor: WovzoColors.orange,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
        selectedColor: WovzoColors.orange,
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
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: WovzoLogo(height: 26),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hey there! 👋',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: WovzoColors.deepBlack,
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
                  backgroundColor: WovzoColors.deepBlack,
                  child: const Text('I', style: TextStyle(color: WovzoColors.orange, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const SizedBox(height: 24),
            
            // Search Bar
            TextField(
              onChanged: _updateSearch,
              decoration: InputDecoration(
                hintText: 'Search brands, categories...',
                prefixIcon: const Icon(Icons.search, color: WovzoColors.deepBlack),
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
            
            const Text(
              'Top Campaigns',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: WovzoColors.deepBlack,
              ),
            ),
            const SizedBox(height: 16),
            
            // Dynamic Campaign Cards from Supabase
            FutureBuilder<List<Map<String, dynamic>>>(
              future: () async {
                final data = await Supabase.instance.client
                    .from('campaigns')
                    .select('*, profiles(name)')
                    .eq('status', 'active')
                    .order('created_at', ascending: false);
                
                final list = List<Map<String, dynamic>>.from(data);
                
                return list.where((campaign) {
                  // Filter by category
                  if (_selectedCategory != 'For You') {
                    final cat = _selectedCategory.toLowerCase();
                    final title = (campaign['title'] ?? '').toString().toLowerCase();
                    final desc = (campaign['description'] ?? '').toString().toLowerCase();
                    final req = (campaign['requirements'] ?? '').toString().toLowerCase();
                    
                    if (!title.contains(cat) && !desc.contains(cat) && !req.contains(cat)) {
                      return false;
                    }
                  }
                  
                  // Filter by search query
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    final title = (campaign['title'] ?? '').toString().toLowerCase();
                    final desc = (campaign['description'] ?? '').toString().toLowerCase();
                    final req = (campaign['requirements'] ?? '').toString().toLowerCase();
                    final brand = (campaign['profiles']?['name'] ?? '').toString().toLowerCase();
                    
                    if (!title.contains(q) && !desc.contains(q) && !req.contains(q) && !brand.contains(q)) {
                      return false;
                    }
                  }
                  
                  return true;
                }).toList();
              }(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: WovzoColors.orange),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                    ),
                  );
                }
                
                final campaigns = snapshot.data ?? [];
                
                if (campaigns.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.search_off, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('No campaigns match your filter.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
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
                        campaignId: campaign['id']?.toString(),
                        brandName: brandName.toString(),
                        campaignTitle: campaign['title'].toString(),
                        budget: '₹${campaign['budget']}',
                        requirements: campaign['requirements'].toString(),
                        color: WovzoColors.orange,
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
        color: isSelected ? WovzoColors.orange : Colors.grey[100],
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_outline, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  requirements,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
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
                backgroundColor: WovzoColors.orangeLight,
                foregroundColor: WovzoColors.orange,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('View Details', style: TextStyle(fontWeight: FontWeight.bold)),
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
        title: const Text('Campaign Details', style: TextStyle(fontWeight: FontWeight.bold, color: WovzoColors.deepBlack)),
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
                  color: WovzoColors.orangeLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: WovzoColors.orange.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    brandName.isNotEmpty ? brandName[0].toUpperCase() : "B",
                    style: const TextStyle(
                      color: WovzoColors.orange,
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
                  color: WovzoColors.deepBlack,
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
                  child: _buildInfoCard('Platform', 'Instagram', Icons.camera_alt_outlined, WovzoColors.orange),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'About the Campaign',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: WovzoColors.deepBlack),
            ),
            const SizedBox(height: 12),
            Text(
              'We are looking for energetic creators to promote our new product launch. You will be provided with the product and a creative brief. We want authentic, engaging content that highlights the core features.',
              style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.5),
            ),
            const SizedBox(height: 32),
            const Text(
              'Requirements & Deliverables',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: WovzoColors.deepBlack),
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
              backgroundColor: WovzoColors.orange,
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WovzoColors.orange,
                    foregroundColor: Colors.white,
                  ),
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
                  return const Center(child: CircularProgressIndicator(color: WovzoColors.orange));
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
                                Expanded(child: Text(campaign['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: WovzoColors.deepBlack))),
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
                                color: WovzoColors.orangeLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.people, size: 16, color: WovzoColors.orange),
                                  const SizedBox(width: 8),
                                  Text('$appsCount Applicants', style: const TextStyle(color: WovzoColors.orange, fontWeight: FontWeight.bold)),
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
                          backgroundColor: WovzoColors.orangeLight,
                          child: Text(profile['name']?[0]?.toUpperCase() ?? 'I', style: const TextStyle(color: WovzoColors.orange, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(profile['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, color: WovzoColors.deepBlack)),
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
  // Profile state
  String _email = '';
  String _name = 'User';
  String _role = 'influencer';
  String _bio = 'Content creator & digital influencer 🚀';
  String _niche = 'Fashion & Lifestyle';
  String _instagram = '';
  String _youtube = '';
  String _location = 'India';
  String _phone = '';
  String _website = '';
  String _avatarUrl = '';

  // Stats
  int _stat1 = 0;
  int _stat2 = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUpdatingPassword = false;

  // Controllers for editing
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _nicheController = TextEditingController();
  final _instagramController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _avatarUrlController = TextEditingController();

  // Password controllers
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final List<String> _niches = [
    'Fashion & Lifestyle',
    'Tech & Gadgets',
    'Fitness & Health',
    'Beauty & Cosmetics',
    'Food & Dining',
    'Travel & Adventure',
    'Gaming & Entertainment',
    'Education & Business',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _nicheController.dispose();
    _instagramController.dispose();
    _youtubeController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _avatarUrlController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    
    // 1. Fetch fresh user from server
    User? user;
    try {
      final userResp = await Supabase.instance.client.auth.getUser();
      user = userResp.user;
    } catch (_) {
      user = Supabase.instance.client.auth.currentUser;
    }

    if (user != null) {
      _email = user.email ?? '';

      // Load user metadata
      final meta = user.userMetadata ?? {};
      if (meta['name'] != null && meta['name'].toString().trim().isNotEmpty) {
        _name = meta['name'].toString().trim();
      }
      if (meta['bio'] != null && meta['bio'].toString().isNotEmpty) {
        _bio = meta['bio'].toString();
      }
      if (meta['niche'] != null && meta['niche'].toString().isNotEmpty) {
        _niche = meta['niche'].toString();
      }
      if (meta['instagram'] != null) _instagram = meta['instagram'].toString();
      if (meta['youtube'] != null) _youtube = meta['youtube'].toString();
      if (meta['location'] != null && meta['location'].toString().isNotEmpty) {
        _location = meta['location'].toString();
      }
      if (meta['phone'] != null) _phone = meta['phone'].toString();
      if (meta['website'] != null) _website = meta['website'].toString();
      if (meta['avatar_url'] != null && meta['avatar_url'].toString().trim().isNotEmpty) {
        _avatarUrl = meta['avatar_url'].toString().trim();
      }
      if (meta['role'] != null && meta['role'].toString().trim().isNotEmpty) {
        _role = meta['role'].toString().trim();
      }

      // Query database profile
      try {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('name, role')
            .eq('id', user.id)
            .maybeSingle();

        if (data != null) {
          if (data['name'] != null &&
              data['name'].toString().trim().isNotEmpty &&
              data['name'].toString().trim() != 'User') {
            _name = data['name'].toString().trim();
          }
          if (data['role'] != null && data['role'].toString().trim().isNotEmpty) {
            _role = data['role'].toString().trim();
          }
        }
      } catch (e) {
        debugPrint('Error loading profiles row: $e');
      }

      // Sync controllers
      _nameController.text = _name;
      _bioController.text = _bio;
      _nicheController.text = _niche;
      _instagramController.text = _instagram;
      _youtubeController.text = _youtube;
      _locationController.text = _location;
      _phoneController.text = _phone;
      _websiteController.text = _website;
      _avatarUrlController.text = _avatarUrl;

      // Query Stats
      await _loadStats(user.id);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStats(String userId) async {
    try {
      if (_role == 'brand') {
        final campaigns = await Supabase.instance.client
            .from('campaigns')
            .select('id')
            .eq('brand_id', userId);
        _stat1 = campaigns.length;

        final apps = await Supabase.instance.client
            .from('applications')
            .select('id, campaigns!inner(brand_id)')
            .eq('campaigns.brand_id', userId);
        _stat2 = apps.length;
      } else {
        final apps = await Supabase.instance.client
            .from('applications')
            .select('id, status')
            .eq('influencer_id', userId);
        _stat1 = apps.length;
        _stat2 = apps.where((a) => a['status'] == 'accepted').length;
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> _saveProfileChanges({
    required StateSetter setModalState,
    required BuildContext modalContext,
  }) async {
    setModalState(() => _isSaving = true);
    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final newName = _nameController.text.trim();
        final newBio = _bioController.text.trim();
        final newNiche = _nicheController.text.trim();
        final newInsta = _instagramController.text.trim();
        final newYt = _youtubeController.text.trim();
        final newLoc = _locationController.text.trim();
        final newPhone = _phoneController.text.trim();
        final newWeb = _websiteController.text.trim();
        final newAvatar = _avatarUrlController.text.trim();

        // 1. Try to update profiles table safely
        try {
          if (newName.isNotEmpty) {
            await Supabase.instance.client.from('profiles').upsert({
              'id': user.id,
              'name': newName,
              'role': _role,
            });
          }
        } catch (e) {
          debugPrint('Notice: profiles table direct update error: $e');
        }

        // 2. Update user metadata in Auth (reliably persists)
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            data: {
              'name': newName,
              'bio': newBio,
              'niche': newNiche,
              'instagram': newInsta,
              'youtube': newYt,
              'location': newLoc,
              'phone': newPhone,
              'website': newWeb,
              'avatar_url': newAvatar,
              'role': _role,
            },
          ),
        );

        if (mounted) {
          setState(() {
            _name = newName.isNotEmpty ? newName : _name;
            _bio = newBio;
            _niche = newNiche;
            _instagram = newInsta;
            _youtube = newYt;
            _location = newLoc;
            _phone = newPhone;
            _website = newWeb;
            _avatarUrl = newAvatar;
          });

          if (modalContext.mounted) {
            Navigator.of(modalContext).pop();
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Profile updated successfully!'),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            content: Text('Error updating profile: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
      try {
        setModalState(() => _isSaving = false);
      } catch (_) {}
    }
  }

  Future<void> _saveAvatarOnly(String url, {required StateSetter setModalState, required BuildContext modalContext}) async {
    setModalState(() => _isSaving = true);
    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            data: {
              'avatar_url': url,
            },
          ),
        );
        if (mounted) {
          setState(() {
            _avatarUrl = url;
            _avatarUrlController.text = url;
          });
          if (modalContext.mounted) {
            Navigator.of(modalContext).pop();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Profile picture updated successfully!'),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating avatar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            content: Text('Error updating photo: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
      try {
        setModalState(() => _isSaving = false);
      } catch (_) {}
    }
  }

  void _showChangeProfilePhotoBottomSheet() {
    String tempAvatarUrl = _avatarUrl;
    final tempController = TextEditingController(text: _avatarUrl);

    final List<Map<String, String>> presets = [
      {'name': 'Avatar 1', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Felix'},
      {'name': 'Avatar 2', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Aneka'},
      {'name': 'Avatar 3', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Milo'},
      {'name': 'Avatar 4', 'url': 'https://api.dicebear.com/7.x/adventurer/png?seed=Zoe'},
      {'name': 'Bot 1', 'url': 'https://api.dicebear.com/7.x/bottts/png?seed=Wovzo1'},
      {'name': 'Bot 2', 'url': 'https://api.dicebear.com/7.x/bottts/png?seed=Wovzo2'},
      {'name': 'Creator Boy', 'url': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150'},
      {'name': 'Creator Girl', 'url': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150'},
      {'name': 'Fashion Stylist', 'url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150'},
      {'name': 'Tech Reviewer', 'url': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Profile Picture',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(modalCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Live Avatar Preview
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: WovzoColors.orange, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: WovzoColors.orange.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor: WovzoColors.deepBlack,
                        foregroundImage: tempAvatarUrl.isNotEmpty ? _getAvatarImageProvider(tempAvatarUrl) : null,
                        onForegroundImageError: tempAvatarUrl.isNotEmpty ? (e, s) {} : null,
                        child: Text(
                          _name.isNotEmpty ? _name[0].toUpperCase() : 'U',
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: WovzoColors.orange),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Direct Gallery / Photos and Camera Buttons
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving
                                  ? null
                                  : () async {
                                      try {
                                        final picker = ImagePicker();
                                        final XFile? image = await picker.pickImage(
                                          source: ImageSource.gallery,
                                          maxWidth: 400,
                                          maxHeight: 400,
                                          imageQuality: 70,
                                        );
                                        if (image != null) {
                                          final bytes = await image.readAsBytes();
                                          final base64Str = base64Encode(bytes);
                                          setModalState(() {
                                            tempAvatarUrl = 'data:image/jpeg;base64,$base64Str';
                                            tempController.text = '';
                                          });
                                        }
                                      } catch (e) {
                                        debugPrint('Gallery pick error: $e');
                                        if (modalCtx.mounted) {
                                          ScaffoldMessenger.of(modalCtx).showSnackBar(
                                            SnackBar(
                                              backgroundColor: Colors.red,
                                              content: Text('Failed to pick from gallery: $e'),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              icon: const Icon(Icons.photo_library, color: Colors.white, size: 20),
                              label: const Text(
                                'Gallery / Photos',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: WovzoColors.orange,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () async {
                                    try {
                                      final picker = ImagePicker();
                                      final XFile? image = await picker.pickImage(
                                        source: ImageSource.camera,
                                        maxWidth: 400,
                                        maxHeight: 400,
                                        imageQuality: 70,
                                      );
                                      if (image != null) {
                                        final bytes = await image.readAsBytes();
                                        final base64Str = base64Encode(bytes);
                                        setModalState(() {
                                          tempAvatarUrl = 'data:image/jpeg;base64,$base64Str';
                                          tempController.text = '';
                                        });
                                      }
                                    } catch (e) {
                                      debugPrint('Camera error: $e');
                                    }
                                  },
                            icon: const Icon(Icons.camera_alt_outlined, color: WovzoColors.orange, size: 18),
                            label: const Text(
                              'Camera',
                              style: TextStyle(color: WovzoColors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: WovzoColors.orange, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: WovzoColors.orangeLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'OR CHOOSE AVATAR PRESET',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 0.5),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Choose an Avatar Preset:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 72,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: presets.length,
                        itemBuilder: (context, i) {
                          final item = presets[i];
                          final isSelected = tempAvatarUrl == item['url'];
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                tempAvatarUrl = item['url']!;
                                tempController.text = item['url']!;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? WovzoColors.orange : Colors.grey.shade300,
                                  width: isSelected ? 3 : 1,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.grey.shade100,
                                foregroundImage: NetworkImage(item['url']!),
                                onForegroundImageError: (e, s) {},
                                child: const Icon(Icons.person, color: Colors.grey),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Or Paste Image URL:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: tempController,
                      decoration: InputDecoration(
                        hintText: 'https://example.com/photo.jpg',
                        prefixIcon: const Icon(Icons.link),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check, color: WovzoColors.orange),
                          onPressed: () {
                            setModalState(() {
                              tempAvatarUrl = tempController.text.trim();
                            });
                          },
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          tempAvatarUrl = val.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () => _saveAvatarOnly(
                                  tempAvatarUrl,
                                  setModalState: setModalState,
                                  modalContext: modalCtx,
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WovzoColors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Save Profile Picture', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    if (tempAvatarUrl.isNotEmpty || _avatarUrl.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () => _saveAvatarOnly(
                                  '',
                                  setModalState: setModalState,
                                  modalContext: modalCtx,
                                ),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text('Remove Photo (Use Initial)', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditProfileBottomSheet() {
    _nameController.text = _name;
    _bioController.text = _bio;
    _nicheController.text = _niche;
    _instagramController.text = _instagram;
    _youtubeController.text = _youtube;
    _locationController.text = _location;
    _phoneController.text = _phone;
    _websiteController.text = _website;
    _avatarUrlController.text = _avatarUrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Profile',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Quick Avatar Preview & Change Photo button
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              _showChangeProfilePhotoBottomSheet();
                            },
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: WovzoColors.deepBlack,
                                  foregroundImage: _avatarUrlController.text.isNotEmpty
                                      ? _getAvatarImageProvider(_avatarUrlController.text)
                                      : (_avatarUrl.isNotEmpty ? _getAvatarImageProvider(_avatarUrl) : null),
                                  onForegroundImageError: (e, s) {},
                                  child: Text(
                                    _name.isNotEmpty ? _name[0].toUpperCase() : 'U',
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: WovzoColors.orange),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: WovzoColors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: () async {
                                  try {
                                    final picker = ImagePicker();
                                    final XFile? image = await picker.pickImage(
                                      source: ImageSource.gallery,
                                      maxWidth: 400,
                                      maxHeight: 400,
                                      imageQuality: 70,
                                    );
                                    if (image != null) {
                                      final bytes = await image.readAsBytes();
                                      final base64Str = base64Encode(bytes);
                                      setModalState(() {
                                        _avatarUrlController.text = 'data:image/jpeg;base64,$base64Str';
                                      });
                                    }
                                  } catch (e) {
                                    debugPrint('Gallery pick error: $e');
                                  }
                                },
                                icon: const Icon(Icons.photo_library_outlined, size: 18, color: WovzoColors.orange),
                                label: const Text('From Gallery', style: TextStyle(color: WovzoColors.orange, fontWeight: FontWeight.bold)),
                              ),
                              const Text(' • ', style: TextStyle(color: Colors.grey)),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _showChangeProfilePhotoBottomSheet();
                                },
                                icon: const Icon(Icons.auto_awesome, size: 16, color: WovzoColors.orange),
                                label: const Text('Presets', style: TextStyle(color: WovzoColors.orange, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _avatarUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Profile Picture URL (Optional)',
                        hintText: 'https://...',
                        prefixIcon: Icon(Icons.image_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name / Brand Name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _bioController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Bio / Tagline',
                        prefixIcon: Icon(Icons.info_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _niches.contains(_nicheController.text) ? _nicheController.text : _niches.first,
                      decoration: const InputDecoration(
                        labelText: 'Category / Niche',
                        prefixIcon: Icon(Icons.category_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: _niches.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => _nicheController.text = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _instagramController,
                      decoration: const InputDecoration(
                        labelText: 'Instagram Handle (@username)',
                        prefixIcon: Icon(Icons.camera_alt_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _youtubeController,
                      decoration: InputDecoration(
                        labelText: _role == 'brand' ? 'Company Website' : 'YouTube Channel / Link',
                        prefixIcon: const Icon(Icons.link),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'City / Location',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number (Optional)',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () => _saveProfileChanges(
                                  setModalState: setModalState,
                                  modalContext: context,
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WovzoColors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text('Save Profile Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showChangePasswordDialog() {
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.lock_reset, color: WovzoColors.orange),
                  SizedBox(width: 8),
                  Text('Change Password'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password (min 6 chars)',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isUpdatingPassword
                      ? null
                      : () async {
                          if (_newPasswordController.text.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password must be at least 6 characters')),
                            );
                            return;
                          }
                          if (_newPasswordController.text != _confirmPasswordController.text) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Passwords do not match')),
                            );
                            return;
                          }
                          setDialogState(() => _isUpdatingPassword = true);
                          try {
                            await Supabase.instance.client.auth.updateUser(
                              UserAttributes(password: _newPasswordController.text),
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Colors.green,
                                  content: Text('Password changed successfully!'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(backgroundColor: Colors.red, content: Text('Error: $e')),
                              );
                            }
                          } finally {
                            if (mounted) setDialogState(() => _isUpdatingPassword = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WovzoColors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: _isUpdatingPassword
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of Wovzo Collab?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBrand = _role.toLowerCase() == 'brand';

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: WovzoColors.orange));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfile,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // 1. TOP HEADER & AVATAR BANNER
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [WovzoColors.deepBlack, WovzoColors.charcoal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Column(
                    children: [
                      // Avatar with edit badge
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          GestureDetector(
                            onTap: _showChangeProfilePhotoBottomSheet,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: WovzoColors.orange, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: WovzoColors.orange.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 44,
                                backgroundColor: WovzoColors.deepBlack,
                                foregroundImage: _avatarUrl.isNotEmpty ? _getAvatarImageProvider(_avatarUrl) : null,
                                onForegroundImageError: _avatarUrl.isNotEmpty ? (e, s) {} : null,
                                child: Text(
                                  _name.isNotEmpty ? _name[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: WovzoColors.orange,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _showChangeProfilePhotoBottomSheet,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: const BoxDecoration(
                                color: WovzoColors.orange,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
                              ),
                              child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // User Name + verified badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: WovzoColors.orange, size: 20),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Email
                      Text(
                        _email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: WovzoColors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: WovzoColors.orange.withOpacity(0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isBrand ? Icons.business : Icons.auto_awesome,
                              color: WovzoColors.orange,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isBrand ? 'BRAND / BUSINESS' : 'CREATOR / INFLUENCER',
                              style: const TextStyle(
                                color: WovzoColors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_bio.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Text(
                            '"$_bio"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 2. QUICK STATS ROW
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: isBrand ? Icons.campaign_rounded : Icons.send_rounded,
                          label: isBrand ? 'Campaigns' : 'Applications',
                          value: '$_stat1',
                          color: WovzoColors.orange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.handshake_rounded,
                          label: isBrand ? 'Applicants' : 'Collabs',
                          value: '$_stat2',
                          color: WovzoColors.deepBlack,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.verified_user_rounded,
                          label: 'Account',
                          value: 'Active',
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 3. PROFILE DETAILS CARD
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Profile Details',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: WovzoColors.deepBlack),
                            ),
                            TextButton.icon(
                              onPressed: _showEditProfileBottomSheet,
                              style: TextButton.styleFrom(foregroundColor: WovzoColors.orange),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit'),
                            ),
                          ],
                        ),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        _buildDetailTile(
                          icon: Icons.category_outlined,
                          title: 'Primary Niche',
                          value: _niche,
                        ),
                        _buildDetailTile(
                          icon: Icons.camera_alt_outlined,
                          title: 'Instagram',
                          value: _instagram.isNotEmpty ? _instagram : 'Not linked',
                        ),
                        _buildDetailTile(
                          icon: isBrand ? Icons.language : Icons.play_circle_outline,
                          title: isBrand ? 'Company Website' : 'YouTube / Channel',
                          value: _youtube.isNotEmpty
                              ? _youtube
                              : (_website.isNotEmpty ? _website : 'Not linked'),
                        ),
                        _buildDetailTile(
                          icon: Icons.location_on_outlined,
                          title: 'Location',
                          value: _location,
                        ),
                        if (_phone.isNotEmpty)
                          _buildDetailTile(
                            icon: Icons.phone_outlined,
                            title: 'Phone',
                            value: _phone,
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 4. ACCOUNT & SETTINGS CARD
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: WovzoColors.orangeLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.lock_outline, color: WovzoColors.orange),
                          ),
                          title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Update your login password', style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showChangePasswordDialog,
                        ),
                        const Divider(height: 1, indent: 64),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.help_outline, color: Colors.amber),
                          ),
                          title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Contact support@wovzo.com', style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Help & Support'),
                                content: const Text(
                                  'For any questions, issues, or partnership inquiries, please contact:\n\nEmail: support@wovzo.com\nWebsite: https://wovzo.com',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1, indent: 64),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.info_outline, color: Colors.grey),
                          ),
                          title: const Text('App Version', style: TextStyle(fontWeight: FontWeight.w600)),
                          trailing: const Text('v1.0.0', style: TextStyle(color: Colors.grey)),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 5. LOGOUT BUTTON
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _confirmLogout,
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text(
                        'Log Out',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: Colors.red.shade50.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ],
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
      final requirementsString = 'Niche: ${_nicheController.text.trim()} • Platform: ${_platformController.text.trim().isEmpty ? 'Instagram' : _platformController.text.trim()}';
      await Supabase.instance.client.from('campaigns').insert({
        'brand_id': userId,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'budget': _budgetController.text.trim(),
        'requirements': requirementsString,
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
                              backgroundColor: WovzoColors.orangeLight,
                              child: Text(u['name']?[0]?.toUpperCase() ?? 'U', style: const TextStyle(color: WovzoColors.orange, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(u['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, color: WovzoColors.deepBlack)),
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
      appBar: AppBar(title: Text(widget.peerName, style: const TextStyle(fontWeight: FontWeight.bold, color: WovzoColors.deepBlack))),
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
                      color: isMe ? WovzoColors.orange : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      msg['content'],
                      style: TextStyle(color: isMe ? Colors.white : WovzoColors.deepBlack),
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
                    backgroundColor: WovzoColors.orange,
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
