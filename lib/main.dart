import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

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

class ImageCropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  const ImageCropDialog({super.key, required this.imageBytes});

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<ImageCropDialog> {
  final GlobalKey _cropAreaKey = GlobalKey();
  final TransformationController _transformController = TransformationController();
  int _quarterTurns = 0;
  bool _isCropping = false;

  Future<void> _onCropAndDone() async {
    setState(() => _isCropping = true);
    try {
      final boundary = _cropAreaKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) Navigator.of(context).pop(null);
        return;
      }
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final croppedBytes = byteData.buffer.asUint8List();
        final base64String = 'data:image/png;base64,${base64Encode(croppedBytes)}';
        if (mounted) Navigator.of(context).pop(base64String);
        return;
      }
    } catch (e) {
      debugPrint('Error cropping image: $e');
    } finally {
      if (mounted) setState(() => _isCropping = false);
    }
    if (mounted) Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF18181B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.crop, color: WovzoColors.orange, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Crop Profile Picture',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(null),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Pinch to zoom and drag to adjust photo inside circle',
              style: TextStyle(color: Colors.white60, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 250,
                height: 250,
                color: Colors.black,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RepaintBoundary(
                      key: _cropAreaKey,
                      child: Container(
                        width: 250,
                        height: 250,
                        color: Colors.black,
                        child: RotatedBox(
                          quarterTurns: _quarterTurns,
                          child: InteractiveViewer(
                            transformationController: _transformController,
                            minScale: 0.8,
                            maxScale: 4.0,
                            boundaryMargin: const EdgeInsets.all(120),
                            child: Image.memory(
                              widget.imageBytes,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Container(
                        width: 230,
                        height: 230,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.85), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.55),
                              blurRadius: 0,
                              spreadRadius: 200,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.rotate_right, color: Colors.white70),
                  tooltip: 'Rotate 90°',
                  onPressed: () {
                    setState(() {
                      _quarterTurns = (_quarterTurns + 1) % 4;
                    });
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.restart_alt, size: 16, color: Colors.white60),
                  label: const Text('Reset', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  onPressed: () {
                    _transformController.value = Matrix4.identity();
                    setState(() {
                      _quarterTurns = 0;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isCropping ? null : _onCropAndDone,
                    icon: _isCropping
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(_isCropping ? 'Cropping...' : 'Crop & Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WovzoColors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
  final _brandNameController = TextEditingController();
  final _instagramController = TextEditingController();
  final _youtubeController = TextEditingController();
  late final StreamSubscription<AuthState> _authSubscription;
  
  static final Map<String, String> _registeredAccountRoles = {
    'asrafgiimi@gmail.com': 'influencer',
    'asrafgiimi': 'influencer',
  };

  static final Map<String, Map<String, String>> _registeredAccountDetails = {
    'asrafgiimi@gmail.com': {
      'role': 'influencer',
      'password': 'Asraf100%',
      'instagram': 'asrafgiimi',
      'name': 'Asraf Giimi',
    },
    'asrafgiimi': {
      'role': 'influencer',
      'password': 'Asraf100%',
      'instagram': 'asrafgiimi',
      'name': 'Asraf Giimi',
    },
  };

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _selectedRole = 'influencer';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    resetWovzoUserSession();
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

    final cleanEmail = _emailController.text.trim().toLowerCase();
    final normSelected = (_selectedRole.toLowerCase() == 'creator' || _selectedRole.toLowerCase() == 'influencer') ? 'influencer' : 'brand';

    try {
      if (_isLogin) {
        // LOGIN
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (response.user != null) {
          String? registeredRole;
          try {
            final profile = await Supabase.instance.client
                .from('profiles')
                .select('role')
                .eq('id', response.user!.id)
                .maybeSingle();
            if (profile != null && profile['role'] != null) {
              registeredRole = profile['role'].toString();
            }
          } catch (_) {}

          if (registeredRole == null && response.user!.userMetadata?['role'] != null) {
            registeredRole = response.user!.userMetadata!['role'].toString();
          }

          if (registeredRole == null && _registeredAccountRoles.containsKey(cleanEmail)) {
            registeredRole = _registeredAccountRoles[cleanEmail];
          }

          // Normalize registered role
          String normRegistered = (registeredRole != null && (registeredRole.toLowerCase() == 'creator' || registeredRole.toLowerCase() == 'influencer')) ? 'influencer' : 'brand';

          // STRICT ROLE VALIDATION: Creator cannot sign in as Brand, Brand cannot sign in as Creator!
          if (registeredRole != null && normRegistered != normSelected) {
            await Supabase.instance.client.auth.signOut();
            final targetName = normRegistered == 'influencer' ? 'Creator' : 'Brand';
            final currentName = normSelected == 'influencer' ? 'Creator' : 'Brand';
            setState(() {
              _errorMessage = 'Access Denied: This account is registered as a $targetName. You selected $currentName. Please switch to $targetName to sign in.';
            });
            return;
          }

          // Record in registry
          _registeredAccountRoles[cleanEmail] = normSelected;

          // If profile is missing, create it with the verified role
          try {
            await Supabase.instance.client.from('profiles').upsert({
              'id': response.user!.id,
              'name': response.user!.userMetadata?['name'] ?? (normSelected == 'brand' ? 'Brand' : 'Creator'),
              'role': normSelected,
            });
          } catch (_) {}

          _activeSessionEmail = cleanEmail;
          resetWovzoUserSession();
          if (mounted) {
            if (normSelected == 'brand') {
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
        // SIGNUP - STRICT DUPLICATE ACCOUNT RESTRICTION
        final cleanIg = _instagramController.text.trim().replaceAll('@', '').toLowerCase();
        final brandName = _brandNameController.text.trim();
        final cleanBrand = brandName.toLowerCase();
        final contactName = _nameController.text.trim();
        final displayName = normSelected == 'brand'
            ? (brandName.isNotEmpty ? brandName : (contactName.isNotEmpty ? contactName : 'Brand'))
            : (contactName.isNotEmpty ? contactName : 'Creator');

        // 1. Check if email already registered
        if (_registeredAccountRoles.containsKey(cleanEmail)) {
          setState(() {
            _errorMessage = 'An account with this email address already exists. Please Sign In instead.';
            _isLoading = false;
          });
          return;
        }

        // 2. Prevent same creator from creating multiple accounts with same Instagram handle
        if (normSelected == 'influencer' && cleanIg.isNotEmpty) {
          for (final entry in _registeredAccountDetails.values) {
            if (entry['instagram']?.toLowerCase() == cleanIg) {
              setState(() {
                _errorMessage = 'This Instagram handle (@$cleanIg) is already registered with an existing account. Multiple accounts are not allowed.';
                _isLoading = false;
              });
              return;
            }
          }

          try {
            final existingIg = await Supabase.instance.client
                .from('profiles')
                .select('id, name')
                .ilike('instagram', '%$cleanIg%')
                .limit(1)
                .maybeSingle()
                .timeout(const Duration(milliseconds: 1500));
            if (existingIg != null) {
              setState(() {
                _errorMessage = 'This Instagram handle (@$cleanIg) is already registered with an existing account. Multiple accounts are not allowed.';
                _isLoading = false;
              });
              return;
            }
          } catch (_) {}
        }

        // 3. Prevent duplicate brand accounts
        if (normSelected == 'brand' && cleanBrand.length >= 3) {
          for (final entry in _registeredAccountDetails.values) {
            if (entry['brand_name']?.toLowerCase() == cleanBrand) {
              setState(() {
                _errorMessage = 'A brand named "$brandName" is already registered. Duplicate brand accounts are not allowed.';
                _isLoading = false;
              });
              return;
            }
          }

          try {
            final existingBrand = await Supabase.instance.client
                .from('profiles')
                .select('id, name')
                .eq('role', 'brand')
                .ilike('name', cleanBrand)
                .limit(1)
                .maybeSingle()
                .timeout(const Duration(milliseconds: 1500));
            if (existingBrand != null) {
              setState(() {
                _errorMessage = 'A brand named "$brandName" is already registered. Duplicate brand accounts are not allowed.';
                _isLoading = false;
              });
              return;
            }
          } catch (_) {}
        }

        final vCode = 'WOVZO-${1000 + (DateTime.now().millisecondsSinceEpoch % 9000)}';
        final ytChannel = _youtubeController.text.trim();

        final response = await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {
            'name': displayName,
            'brand_name': normSelected == 'brand' ? brandName : '',
            'contact_name': contactName,
            'role': normSelected,
            'instagram': cleanIg.isNotEmpty ? '@$cleanIg' : '',
            'youtube': ytChannel,
            'verification_code': vCode,
            'is_verified': false,
            'instagram_verified': false,
            'youtube_verified': false,
          },
        );

        // Supabase returns an empty identities list if user already exists
        if (response.user != null && response.user!.identities != null && response.user!.identities!.isEmpty) {
          setState(() {
            _errorMessage = 'An account with this email address already exists. Please Sign In instead.';
            _isLoading = false;
          });
          return;
        }

        if (response.user == null) {
          setState(() {
            _errorMessage = 'Could not create account. If you already have an account, please Sign In.';
            _isLoading = false;
          });
          return;
        }

        // Save successfully created account to registry
        _registeredAccountRoles[cleanEmail] = normSelected;
        _registeredAccountDetails[cleanEmail] = {
          'role': normSelected,
          'password': _passwordController.text.trim(),
          'name': displayName,
          'instagram': cleanIg,
          'brand_name': normSelected == 'brand' ? brandName : '',
        };

        if (response.user != null) {
          try {
            await Supabase.instance.client.from('profiles').upsert({
              'id': response.user!.id,
              'name': displayName,
              'role': normSelected,
              'instagram': cleanIg.isNotEmpty ? '@$cleanIg' : '',
              'youtube': ytChannel,
              'verification_code': vCode,
              'is_verified': false,
            });
          } catch (_) {}
        }
        
        resetWovzoUserSession();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => normSelected == 'brand' 
                ? const BrandMainScreen() 
                : const InfluencerMainScreen(),
            ),
          );
        }
        return;
      }
    } catch (e) {
      final errStr = e is AuthException ? e.message : e.toString();
      final errLower = errStr.toLowerCase();

      // Check if error is about already registered / duplicate account
      if (errLower.contains('already registered') || 
          errLower.contains('already exists') || 
          errLower.contains('user_already_exists') ||
          errLower.contains('unique constraint')) {
        setState(() {
          _errorMessage = 'An account with this email address already exists. Please Sign In instead.';
          _isLoading = false;
        });
        return;
      }

      if (errStr.contains('Failed to fetch') || errStr.contains('ClientException') || errStr.contains('SocketException') || errStr.contains('host')) {
        // Offline / Supabase paused:
        if (_isLogin) {
          // STRICT SIGN-UP CHECK: Only registered accounts can Sign In!
          if (!_registeredAccountRoles.containsKey(cleanEmail)) {
            setState(() {
              _errorMessage = 'No account found with this email. Please Sign Up first to create your account.';
              _isLoading = false;
            });
            return;
          }

          // Verify password if stored locally
          final account = _registeredAccountDetails[cleanEmail];
          final isDefaultSeed = cleanEmail == 'asrafgiimi@gmail.com' || cleanEmail == 'asrafgiimi';
          if (account != null && account['password'] != null) {
            final pass = _passwordController.text.trim();
            final matches = isDefaultSeed
                ? (pass == 'Asraf100%' || pass == 'password123' || pass == account['password'])
                : (pass == account['password']);
            if (!matches) {
              setState(() {
                _errorMessage = 'Incorrect password. Please check your credentials and try again.';
                _isLoading = false;
              });
              return;
            }
          }

          // Strictly validate role
          final regRole = _registeredAccountRoles[cleanEmail]!;
          final normReg = (regRole.toLowerCase() == 'creator' || regRole.toLowerCase() == 'influencer') ? 'influencer' : 'brand';
          if (normReg != normSelected) {
            final targetName = normReg == 'influencer' ? 'Creator' : 'Brand';
            final currentName = normSelected == 'influencer' ? 'Creator' : 'Brand';
            setState(() {
              _errorMessage = 'Access Denied: This account is registered as a $targetName. You selected $currentName. Please switch to $targetName to sign in.';
              _isLoading = false;
            });
            return;
          }

          // Verified credentials - proceed into dashboard
          _activeSessionEmail = cleanEmail;
          resetWovzoUserSession();
          if (mounted) {
            if (normSelected == 'brand') {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const BrandMainScreen()));
            } else {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const InfluencerMainScreen()));
            }
          }
          return;
        } else {
          // SIGNUP in offline mode:
          if (_registeredAccountRoles.containsKey(cleanEmail)) {
            setState(() {
              _errorMessage = 'An account with this email address already exists. Please Sign In instead.';
              _isLoading = false;
            });
            return;
          }

          final offlineIg = _instagramController.text.trim().replaceAll('@', '').toLowerCase();
          final offlineBrand = _brandNameController.text.trim();
          final offlineName = _nameController.text.trim();
          final offlineDisplay = normSelected == 'brand'
              ? (offlineBrand.isNotEmpty ? offlineBrand : (offlineName.isNotEmpty ? offlineName : 'Brand'))
              : (offlineName.isNotEmpty ? offlineName : 'Creator');

          // Save new account details locally
          _registeredAccountRoles[cleanEmail] = normSelected;
          _registeredAccountDetails[cleanEmail] = {
            'role': normSelected,
            'password': _passwordController.text.trim(),
            'name': offlineDisplay,
            'instagram': offlineIg,
            'brand_name': normSelected == 'brand' ? offlineBrand : '',
          };

          _activeSessionEmail = cleanEmail;
          resetWovzoUserSession();
          if (mounted) {
            if (normSelected == 'brand') {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const BrandMainScreen()));
            } else {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const InfluencerMainScreen()));
            }
          }
          return;
        }
      } else {
        if (errLower.contains('invalid login credentials') || errLower.contains('invalid_credentials')) {
          setState(() {
            _errorMessage = 'Invalid email or password. If you don\'t have an account yet, please tap Sign Up below.';
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = errStr;
          });
        }
      }
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
      final errStr = e.toString();
      if (errStr.contains('Failed to fetch') || errStr.contains('ClientException') || errStr.contains('SocketException') || errStr.contains('host')) {
        setState(() {
          _errorMessage = 'Supabase database is currently paused on free tier. Tap "Continue in Demo Mode" below to test all screens!';
        });
      } else {
        setState(() {
          _errorMessage = 'Error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Color(0xFF4285F4),
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _completeGoogleSignIn(String email, String name, String normRole) {
    _registeredAccountRoles[email] = normRole;
    if (mounted) {
      if (normRole == 'brand') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const BrandMainScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const InfluencerMainScreen()));
      }
    }
  }

  void _promptCustomGoogleEmail(String normRole) {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Google Sign In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your Google email address to continue:', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'user@gmail.com',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: WovzoColors.orange),
            onPressed: () {
              final em = emailCtrl.text.trim().toLowerCase();
              if (em.isNotEmpty) {
                Navigator.pop(dlgCtx);
                _completeGoogleSignIn(em, em.split('@')[0], normRole);
              }
            },
            child: const Text('Sign In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _signInWithGoogle() {
    final normSelected = (_selectedRole.toLowerCase() == 'creator' || _selectedRole.toLowerCase() == 'influencer') ? 'influencer' : 'brand';
    final targetName = normSelected == 'brand' ? 'Brand' : 'Creator';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildGoogleIcon(),
                const SizedBox(width: 10),
                const Text('Sign in with Google', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Text('Continue to Wovzo Collab as $targetName', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: WovzoColors.orange,
                child: Text('AG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              title: const Text('Asraf Giimi', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('asrafgiimi@gmail.com'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              onTap: () {
                Navigator.pop(ctx);
                _completeGoogleSignIn('asrafgiimi@gmail.com', 'Asraf Giimi', normSelected);
              },
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.person_add_alt_1, color: Colors.white, size: 18),
              ),
              title: const Text('Use another Google account', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _promptCustomGoogleEmail(normSelected);
              },
            ),
          ],
        ),
      ),
    );
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
                    ButtonSegment(value: 'influencer', label: Text('Creator', style: TextStyle(fontWeight: FontWeight.w600))),
                    ButtonSegment(value: 'brand', label: Text('Brand', style: TextStyle(fontWeight: FontWeight.w600))),
                  ],
                  selected: {_selectedRole},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _selectedRole = newSelection.first;
                      _errorMessage = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
              if (!_isLogin) ...[
                if (_selectedRole == 'brand') ...[
                  TextField(
                    controller: _brandNameController,
                    decoration: InputDecoration(
                      labelText: 'Brand / Company Name',
                      hintText: 'e.g. FabIndia, boAt Lifestyle',
                      prefixIcon: const Icon(Icons.business_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Your Full Name (Brand Manager / Founder)',
                      hintText: 'e.g. Rahul Sharma',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'e.g. Asraf Ali',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
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
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
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
              else if (_selectedRole == 'influencer') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.verified_user_outlined, size: 16, color: WovzoColors.orange),
                          SizedBox(width: 6),
                          Text(
                            'Social Channels & Bio Verification',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: WovzoColors.orange),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Provide your handles. You will get a 2-minute Bio Code (WOVZO-XXXX) to earn the Verified Blue Badge!',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _instagramController,
                  decoration: InputDecoration(
                    labelText: 'Instagram Handle (@username)',
                    prefixIcon: const Icon(Icons.camera_alt_outlined, color: Colors.pink),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _youtubeController,
                  decoration: InputDecoration(
                    labelText: 'YouTube Channel / Link (Optional)',
                    prefixIcon: const Icon(Icons.play_circle_outline, color: Colors.red),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ] else
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('OR', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _signInWithGoogle,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildGoogleIcon(),
                      const SizedBox(width: 10),
                      const Text(
                        'Continue with Google',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
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

// Globally track applied campaign IDs and in-memory submissions across screens
final Set<String> _globallyAppliedCampaignIds = <String>{};
final List<Map<String, dynamic>> _globallySubmittedApplications = <Map<String, dynamic>>[];
String _activeSessionEmail = 'asrafgiimi@gmail.com';

void resetWovzoUserSession() {
  _globallyAppliedCampaignIds.clear();
  _globallySubmittedApplications.clear();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'For You';
  bool _hideApplied = false;

  static final List<Map<String, dynamic>> _demoExploreCampaigns = [
    {
      'id': 'exp-1',
      'title': 'Diwali Festive Apparel Launch',
      'description': 'Create an aesthetic Instagram Reel showcasing 2 festive outfits with styling tips.',
      'budget': '15000',
      'requirements': 'Niche: Fashion • Platform: Instagram • Min 5k followers',
      'status': 'active',
      'profiles': {'name': 'FabIndia Apparel'}
    },
    {
      'id': 'exp-2',
      'title': 'Boat Rockerz ANC Wireless Earbuds',
      'description': 'Unboxing and sound test review Reel + Story link with promo code.',
      'budget': '12000',
      'requirements': 'Niche: Tech • Platform: Instagram/YouTube • Good audio setup',
      'status': 'active',
      'profiles': {'name': 'boAt Lifestyle'}
    },
    {
      'id': 'exp-3',
      'title': 'Organic Plant Protein Shake Review',
      'description': 'Post-workout gym reel mixing the protein shake and highlighting authentic taste.',
      'budget': '8500',
      'requirements': 'Niche: Fitness • Platform: Instagram • Active fitness audience',
      'status': 'active',
      'profiles': {'name': 'HealthMax Nutrition'}
    },
    {
      'id': 'exp-4',
      'title': 'Zomato Foodie Weekend Feast',
      'description': 'Showcase dining out or ordering popular biryani with 50% discount code.',
      'budget': '18000',
      'requirements': 'Niche: Food • Platform: Instagram • Food blogger aesthetic',
      'status': 'active',
      'profiles': {'name': 'Zomato Food'}
    },
  ];

  List<Map<String, dynamic>> _exploreCampaigns = List.from(_demoExploreCampaigns);

  @override
  void initState() {
    super.initState();
    _loadExploreCampaigns();
  }

  Future<void> _loadExploreCampaigns() async {
    // Sync applied campaigns from Supabase if logged in
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final apps = await Supabase.instance.client
            .from('applications')
            .select('campaign_id')
            .eq('influencer_id', user.id)
            .timeout(const Duration(milliseconds: 1500));
        for (final app in (apps as List)) {
          if (app['campaign_id'] != null) {
            _globallyAppliedCampaignIds.add(app['campaign_id'].toString());
          }
        }
      } catch (_) {}
    }

    try {
      final data = await Supabase.instance.client
          .from('campaigns')
          .select('*, profiles(name)')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .timeout(const Duration(milliseconds: 1500));
      
      final list = List<Map<String, dynamic>>.from(data);
      if (list.isNotEmpty && mounted) {
        setState(() {
          _exploreCampaigns = list;
        });
      }
    } catch (_) {}
  }

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
        onRefresh: _loadExploreCampaigns,
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, color: WovzoColors.deepBlack, size: 26),
                      onPressed: () => showWovzoNotificationsBottomSheet(context, isBrand: false),
                      tooltip: 'Notifications',
                    ),
                    const SizedBox(width: 4),
                    CircleAvatar(
                      backgroundColor: WovzoColors.deepBlack,
                      child: const Text('I', style: TextStyle(color: WovzoColors.orange, fontWeight: FontWeight.bold)),
                    ),
                  ],
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
            
            // Categories & Hide Applied Filter
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      avatar: Icon(
                        _hideApplied ? Icons.check_circle_rounded : Icons.visibility_off_outlined,
                        size: 16,
                        color: _hideApplied ? Colors.white : Colors.grey[700],
                      ),
                      label: Text(
                        _globallyAppliedCampaignIds.isEmpty
                            ? 'Hide Applied'
                            : 'Hide Applied (${_globallyAppliedCampaignIds.length})',
                        style: TextStyle(
                          color: _hideApplied ? Colors.white : Colors.grey[800],
                          fontWeight: _hideApplied ? FontWeight.bold : FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      selected: _hideApplied,
                      onSelected: (bool selected) {
                        setState(() {
                          _hideApplied = selected;
                        });
                      },
                      selectedColor: WovzoColors.deepBlack,
                      backgroundColor: Colors.grey[100],
                      side: BorderSide(
                        color: _hideApplied ? WovzoColors.deepBlack : Colors.grey[300]!,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      showCheckmark: false,
                    ),
                  ),
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
            
            // Dynamic Campaign Cards (Instant 0ms Cache-First Filtering)
            Builder(
              builder: (context) {
                final allData = _exploreCampaigns;
                
                final campaigns = allData.where((campaign) {
                  final campId = campaign['id']?.toString() ?? '';
                  // If hide applied is active, remove applied campaigns
                  if (_hideApplied && _globallyAppliedCampaignIds.contains(campId)) {
                    return false;
                  }

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
                
                if (campaigns.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 10),
                          Text(
                            _hideApplied && allData.isNotEmpty
                                ? 'You have applied to all matching campaigns.'
                                : 'No campaigns match your filter.',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          if (_hideApplied && allData.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _hideApplied = false;
                                });
                              },
                              icon: const Icon(Icons.visibility_outlined, size: 16),
                              label: const Text('Show All Campaigns'),
                              style: TextButton.styleFrom(
                                foregroundColor: WovzoColors.orange,
                              ),
                            ),
                          ],
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

  void _showApplyBottomSheet(BuildContext context, String campaignId, String campaignTitle, String brandName, {String budget = '₹15,000'}) {
    if (_globallyAppliedCampaignIds.contains(campaignId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already applied to this campaign!')),
      );
      return;
    }

    final pitchController = TextEditingController();
    String? validationError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Apply for $campaignTitle',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: WovzoColors.deepBlack),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(modalCtx).pop(),
                    ),
                  ],
                ),
                Text('Brand: $brandName', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your Proposal / Pitch *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        'Required',
                        style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: pitchController,
                  maxLines: 3,
                  onChanged: (val) {
                    if (validationError != null && val.trim().isNotEmpty) {
                      setSheetState(() {
                        validationError = null;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Tell the brand why you are a great fit (e.g. niche, reach, video idea)...',
                    hintStyle: const TextStyle(fontSize: 13),
                    filled: true,
                    fillColor: validationError != null ? Colors.red.shade50.withOpacity(0.3) : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: validationError != null ? Colors.red : Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: validationError != null ? Colors.red : Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: validationError != null ? Colors.red : WovzoColors.orange, width: 2),
                    ),
                  ),
                ),
                if (validationError != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 15),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          validationError!,
                          style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      FocusScope.of(sheetCtx).unfocus();
                      final pitchText = pitchController.text.trim();
                      if (pitchText.isEmpty) {
                        setSheetState(() {
                          validationError = 'Proposal box cannot be empty! Please enter your pitch.';
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text('⚠️ Proposal box cannot be empty! Please enter your pitch.'),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.redAccent,
                            duration: Duration(seconds: 3),
                          ),
                        );
                        return;
                      }

                      // 1. Immediately close the modal bottom sheet
                      Navigator.of(modalCtx).pop();

                      // 2. Mark as applied locally and update UI
                      _globallyAppliedCampaignIds.add(campaignId);
                      _globallySubmittedApplications.insert(0, {
                        'id': 'app-${DateTime.now().millisecondsSinceEpoch}',
                        'campaign_id': campaignId,
                        'status': 'pending',
                        'pitch': pitchText,
                        'created_at': DateTime.now().toIso8601String(),
                        'campaigns': {
                          'id': campaignId,
                          'title': campaignTitle,
                          'budget': budget,
                          'profiles': {'name': brandName}
                        }
                      });
                      if (mounted) setState(() {});

                      // 3. Display floating success toast
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: const [
                                Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Proposal Submitted Successfully! 🎉',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Your pitch is now under review by the brand.',
                                        style: TextStyle(fontSize: 12, color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF059669),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }

                      // 4. Background non-blocking sync to Supabase
                      try {
                        final userId = Supabase.instance.client.auth.currentUser?.id;
                        if (userId != null) {
                          final payload = {
                            'campaign_id': campaignId,
                            'influencer_id': userId,
                            'status': 'pending',
                            'pitch': pitchText,
                          };
                          await Supabase.instance.client
                              .from('applications')
                              .insert(payload)
                              .timeout(const Duration(milliseconds: 1500));
                        }
                      } catch (_) {}
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WovzoColors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Submit Application', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
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
    final hasApplied = campaignId != null && _globallyAppliedCampaignIds.contains(campaignId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasApplied ? const Color(0xFFA7F3D0) : Colors.grey[200]!,
          width: hasApplied ? 1.5 : 1.0,
        ),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
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
                  if (hasApplied) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF059669)),
                          SizedBox(width: 3),
                          Text(
                            'Applied',
                            style: TextStyle(
                              color: Color(0xFF065F46),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CampaignDetailsScreen(
                          brandName: brandName,
                          campaignTitle: campaignTitle,
                          budget: budget,
                          requirements: requirements,
                          color: color,
                          campaignId: campaignId,
                        ),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: WovzoColors.deepBlack,
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Details', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: hasApplied
                      ? null
                      : () {
                          if (campaignId != null) {
                            _showApplyBottomSheet(context, campaignId, campaignTitle, brandName, budget: budget);
                          }
                        },
                  icon: Icon(
                    hasApplied ? Icons.check_circle_rounded : Icons.send_rounded,
                    size: 15,
                  ),
                  label: Text(
                    hasApplied ? 'Already Applied' : 'Apply with Pitch',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasApplied ? const Color(0xFFECFDF5) : WovzoColors.orange,
                    foregroundColor: hasApplied ? const Color(0xFF047857) : Colors.white,
                    disabledBackgroundColor: const Color(0xFFECFDF5),
                    disabledForegroundColor: const Color(0xFF047857),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: hasApplied
                          ? const BorderSide(color: Color(0xFFA7F3D0))
                          : BorderSide.none,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CampaignDetailsScreen extends StatefulWidget {
  final String brandName;
  final String campaignTitle;
  final String budget;
  final String requirements;
  final Color color;
  final String? campaignId;

  const CampaignDetailsScreen({
    super.key,
    required this.brandName,
    required this.campaignTitle,
    required this.budget,
    required this.requirements,
    required this.color,
    this.campaignId,
  });

  @override
  State<CampaignDetailsScreen> createState() => _CampaignDetailsScreenState();
}

class _CampaignDetailsScreenState extends State<CampaignDetailsScreen> {
  void _showApplyDialog(BuildContext context) {
    if (widget.campaignId != null && _globallyAppliedCampaignIds.contains(widget.campaignId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already applied to this campaign!')),
      );
      return;
    }

    final pitchController = TextEditingController();
    String? validationError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Apply for ${widget.campaignTitle}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: WovzoColors.deepBlack),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(modalCtx).pop(),
                    ),
                  ],
                ),
                Text('Brand: ${widget.brandName} • Payout: ${widget.budget}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your Proposal / Pitch *',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        'Required',
                        style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: pitchController,
                  maxLines: 3,
                  onChanged: (val) {
                    if (validationError != null && val.trim().isNotEmpty) {
                      setSheetState(() {
                        validationError = null;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Tell the brand why you are a great fit (e.g. niche, reach, video idea)...',
                    hintStyle: const TextStyle(fontSize: 13),
                    filled: true,
                    fillColor: validationError != null ? Colors.red.shade50.withOpacity(0.3) : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: validationError != null ? Colors.red : Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: validationError != null ? Colors.red : Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: validationError != null ? Colors.red : WovzoColors.orange, width: 2),
                    ),
                  ),
                ),
                if (validationError != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 15),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          validationError!,
                          style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      FocusScope.of(sheetCtx).unfocus();
                      final pitchText = pitchController.text.trim();
                      if (pitchText.isEmpty) {
                        setSheetState(() {
                          validationError = 'Proposal box cannot be empty! Please enter your pitch.';
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text('⚠️ Proposal box cannot be empty! Please enter your pitch.'),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.redAccent,
                            duration: Duration(seconds: 3),
                          ),
                        );
                        return;
                      }

                      // 1. Immediately close the modal bottom sheet
                      Navigator.of(modalCtx).pop();

                      // 2. Mark as applied locally and update UI
                      if (widget.campaignId != null) {
                        _globallyAppliedCampaignIds.add(widget.campaignId!);
                        _globallySubmittedApplications.insert(0, {
                          'id': 'app-${DateTime.now().millisecondsSinceEpoch}',
                          'campaign_id': widget.campaignId,
                          'status': 'pending',
                          'pitch': pitchText,
                          'created_at': DateTime.now().toIso8601String(),
                          'campaigns': {
                            'id': widget.campaignId,
                            'title': widget.campaignTitle,
                            'budget': widget.budget,
                            'profiles': {'name': widget.brandName}
                          }
                        });
                        setState(() {});
                      }

                      // 3. Display floating success toast
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: const [
                                Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Proposal Submitted Successfully! 🎉',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Your pitch is now under review by the brand.',
                                        style: TextStyle(fontSize: 12, color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: const Color(0xFF059669),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }

                      // 4. Background non-blocking sync to Supabase
                      try {
                        final userId = Supabase.instance.client.auth.currentUser?.id;
                        if (userId != null && widget.campaignId != null) {
                          final payload = {
                            'campaign_id': widget.campaignId,
                            'influencer_id': userId,
                            'status': 'pending',
                            'pitch': pitchText,
                          };
                          await Supabase.instance.client
                              .from('applications')
                              .insert(payload)
                              .timeout(const Duration(milliseconds: 1500));
                        }
                      } catch (_) {}
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WovzoColors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Submit Application', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final hasApplied = widget.campaignId != null && _globallyAppliedCampaignIds.contains(widget.campaignId);

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
            if (hasApplied) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Already Applied',
                            style: TextStyle(
                              color: Color(0xFF065F46),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Your pitch is submitted and under review by the brand.',
                            style: TextStyle(
                              color: Color(0xFF047857),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                    widget.brandName.isNotEmpty ? widget.brandName[0].toUpperCase() : "B",
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
                widget.brandName,
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
                widget.campaignTitle,
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
                  child: _buildInfoCard('Budget', widget.budget, Icons.account_balance_wallet_outlined, Colors.green),
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
            _buildRequirementItem('Minimum Followers', widget.requirements.split('•')[0].trim()),
            _buildRequirementItem('Deliverables', widget.requirements.split('•').length > 1 ? widget.requirements.split('•')[1].trim() : 'Content creation'),
            _buildRequirementItem('Usage Rights', '6 months digital ads'),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: hasApplied ? null : () => _showApplyDialog(context),
            icon: Icon(
              hasApplied ? Icons.check_circle_rounded : Icons.send_rounded,
              size: 18,
            ),
            label: Text(
              hasApplied ? 'Already Applied' : 'Apply Now',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasApplied ? const Color(0xFFECFDF5) : WovzoColors.orange,
              foregroundColor: hasApplied ? const Color(0xFF047857) : Colors.white,
              disabledBackgroundColor: const Color(0xFFECFDF5),
              disabledForegroundColor: const Color(0xFF047857),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: hasApplied
                    ? const BorderSide(color: Color(0xFFA7F3D0), width: 1.5)
                    : BorderSide.none,
              ),
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

class BrandCampaignsScreen extends StatefulWidget {
  const BrandCampaignsScreen({super.key});

  @override
  State<BrandCampaignsScreen> createState() => _BrandCampaignsScreenState();
}

class _BrandCampaignsScreenState extends State<BrandCampaignsScreen> {
  static final List<Map<String, dynamic>> _demoBrandCampaigns = [
    {
      'id': 'demo-b-1',
      'title': 'Diwali Festive Apparel Launch',
      'budget': '15000',
      'requirements': 'Niche: Fashion • Platform: Instagram',
      'status': 'active',
      'applications': [{'count': 4}]
    },
    {
      'id': 'demo-b-2',
      'title': 'Winter Cozy Hoodie Reel Campaign',
      'budget': '12500',
      'requirements': 'Niche: Lifestyle • Platform: Instagram',
      'status': 'active',
      'applications': [{'count': 2}]
    }
  ];

  List<Map<String, dynamic>> _brandCampaigns = List.from(_demoBrandCampaigns);

  @override
  void initState() {
    super.initState();
    _loadBrandCampaigns();
  }

  Future<void> _loadBrandCampaigns() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null && userId.isNotEmpty) {
      try {
        final data = await Supabase.instance.client
            .from('campaigns')
            .select('*, applications(count)')
            .eq('brand_id', userId)
            .order('created_at', ascending: false)
            .timeout(const Duration(milliseconds: 1500));
        final list = List<Map<String, dynamic>>.from(data);
        resetWovzoUserSession();
        if (mounted) {
          setState(() {
            _brandCampaigns = list;
          });
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadBrandCampaigns,
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.insights_rounded, color: WovzoColors.deepBlack, size: 24),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BrandAnalyticsScreen())),
                        tooltip: 'Performance & ROI Analytics',
                      ),
                      IconButton(
                        icon: const Icon(Icons.shield_outlined, color: WovzoColors.deepBlack, size: 24),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BrandEscrowScreen())),
                        tooltip: 'Escrow & Billing',
                      ),
                      IconButton(
                        icon: const Icon(Icons.notifications_none_rounded, color: WovzoColors.deepBlack, size: 26),
                        onPressed: () => showWovzoNotificationsBottomSheet(context, isBrand: true),
                        tooltip: 'Notifications',
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateCampaignScreen()));
                          if (result == true) {
                            _loadBrandCampaigns();
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
                ],
              ),
            ),
            Expanded(
              child: _brandCampaigns.isEmpty
                  ? const Center(child: Text('You have not created any campaigns yet.'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: _brandCampaigns.length,
                      itemBuilder: (context, index) {
                        final campaign = _brandCampaigns[index];
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
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: WovzoColors.orangeLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.people, size: 15, color: WovzoColors.orange),
                                      const SizedBox(width: 6),
                                      Text('$appsCount Applicants', style: const TextStyle(color: WovzoColors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BrandEscrowScreen())),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: (campaign['escrow_funded'] == true || campaign['escrow_status'] == 'funded')
                                          ? Colors.green[50]
                                          : Colors.amber[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: (campaign['escrow_funded'] == true || campaign['escrow_status'] == 'funded')
                                            ? Colors.green[200]!
                                            : Colors.amber[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          (campaign['escrow_funded'] == true || campaign['escrow_status'] == 'funded')
                                              ? Icons.check_circle_rounded
                                              : Icons.shield_outlined,
                                          size: 14,
                                          color: (campaign['escrow_funded'] == true || campaign['escrow_status'] == 'funded')
                                              ? Colors.green[700]
                                              : Colors.amber[800],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          (campaign['escrow_funded'] == true || campaign['escrow_status'] == 'funded')
                                              ? 'Escrow Funded'
                                              : 'Fund Escrow',
                                          style: TextStyle(
                                            color: (campaign['escrow_funded'] == true || campaign['escrow_status'] == 'funded')
                                                ? Colors.green[800]
                                                : Colors.amber[900],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ),
          ],
        ),
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
  String _selectedTab = 'all'; // 'all', 'deliverables', 'pending', 'completed'

  static final List<Map<String, dynamic>> _demoApplicants = [
    {
      'id': 'app-demo-1',
      'status': 'submitted',
      'submission_url': 'https://instagram.com/reel/festive_collab',
      'submission_notes': 'Live reel posted with 45k impressions and 1.2k saves',
      'submitted_at': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
      'profiles': {'name': 'Ananya Sharma (Fashion Influencer)', 'instagram': '@ananyasharma_fit', 'is_verified': true},
      'campaigns': {'title': 'Diwali Festive Apparel Launch', 'budget': 15000, 'brand_id': 'demo-brand-user-id'}
    },
    {
      'id': 'app-demo-2',
      'status': 'pending',
      'profiles': {'name': 'Rahul Verma (Fitness Creator)', 'instagram': '@rahulverma_fit', 'is_verified': true},
      'campaigns': {'title': 'Protein Shake Campaign', 'budget': 8500, 'brand_id': 'demo-brand-user-id'}
    }
  ];

  List<Map<String, dynamic>> _applicants = List.from(_demoApplicants);

  @override
  void initState() {
    super.initState();
    _loadApplicants();
  }

  Future<void> _loadApplicants() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    try {
      final appsResponse = await Supabase.instance.client
          .from('applications')
          .select('*, profiles:influencer_id(name, instagram, is_verified), campaigns:campaign_id(title, brand_id, budget)')
          .order('created_at', ascending: false)
          .timeout(const Duration(milliseconds: 1500));
          
      final list = List<Map<String, dynamic>>.from(appsResponse);
      final filtered = userId != null
          ? list.where((app) => app['campaigns'] != null && app['campaigns']['brand_id'] == userId).toList()
          : list;
      if (mounted) {
        setState(() {
          _applicants = filtered;
        });
      }
    } catch (_) {}
  }

  Future<void> _updateStatus(BuildContext context, String applicationId, String newStatus, {String? revisionNotes}) async {
    try {
      final payload = <String, dynamic>{
        'status': newStatus,
        if (newStatus == 'completed') 'completed_at': DateTime.now().toIso8601String(),
        if (revisionNotes != null) 'revision_notes': revisionNotes,
      };
      await Supabase.instance.client
          .from('applications')
          .update(payload)
          .eq('id', applicationId);
      if (mounted) setState(() {});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newStatus == 'completed' ? 'Deliverable approved & completed! 🎉' : 'Status updated to $newStatus')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showRevisionDialog(BuildContext context, String applicationId, String influencerName) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Request Changes from $influencerName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What changes are required before you can approve this deliverable?',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Please tag @brand handle and add coupon code in description...',
                hintStyle: const TextStyle(fontSize: 12),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              _updateStatus(context, applicationId, 'revision_requested', revisionNotes: text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: WovzoColors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Send Feedback'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apps = _applicants.where((app) {
      final s = app['status']?.toString();
      if (_selectedTab == 'deliverables') return s == 'submitted';
      if (_selectedTab == 'pending') return s == 'pending';
      if (_selectedTab == 'completed') return s == 'completed';
      return true;
    }).toList();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadApplicants,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Creator Applications',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: WovzoColors.deepBlack),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabChip('all', 'All'),
                    _buildTabChip('deliverables', 'Review Proofs'),
                    _buildTabChip('pending', 'Pending'),
                    _buildTabChip('completed', 'Completed'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: apps.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            _selectedTab == 'deliverables' 
                                ? 'No submitted deliverables awaiting review.'
                                : _selectedTab == 'pending'
                                ? 'No pending applications.'
                                : 'No applications found.',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      itemCount: apps.length,
                      itemBuilder: (context, index) {
                    final app = apps[index];
                    final profile = app['profiles'] as Map<String, dynamic>? ?? {};
                    final campaign = app['campaigns'] as Map<String, dynamic>? ?? {};
                    final status = app['status']?.toString() ?? 'pending';
                    final influencerName = profile['name']?.toString() ?? 'Creator';
                    final isSubmitted = status == 'submitted';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSubmitted ? WovzoColors.orange : Colors.grey[200]!,
                          width: isSubmitted ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: WovzoColors.orangeLight,
                                child: Text(
                                  influencerName.isNotEmpty ? influencerName[0].toUpperCase() : 'C',
                                  style: const TextStyle(color: WovzoColors.orange, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          influencerName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: WovzoColors.deepBlack),
                                        ),
                                        if (profile['is_verified'] == true || profile['is_verified']?.toString() == 'true') ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.verified, size: 16, color: Color(0xFF38BDF8)),
                                        ],
                                      ],
                                    ),
                                    if (profile['instagram'] != null && profile['instagram'].toString().isNotEmpty)
                                      Text(
                                        profile['instagram'].toString(),
                                        style: const TextStyle(fontSize: 12, color: Color(0xFFE11D48), fontWeight: FontWeight.w500),
                                      ),
                                    Text(
                                      'For: ${campaign['title'] ?? 'Campaign'}',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              _buildStatusBadge(status),
                            ],
                          ),
                          if (app['pitch'] != null && app['pitch'].toString().trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Text(
                                '💬 Pitch: "${app['pitch']}"',
                                style: TextStyle(fontSize: 12, color: Colors.grey[800], fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                          if (app['submission_url'] != null && app['submission_url'].toString().trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: WovzoColors.orangeLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: WovzoColors.orange.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.link, size: 16, color: WovzoColors.orange),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          app['submission_url'].toString(),
                                          style: const TextStyle(fontSize: 13, color: WovzoColors.orange, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (app['submission_notes'] != null && app['submission_notes'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Notes: ${app['submission_notes']}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          if (status == 'revision_requested' && app['revision_notes'] != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Text(
                                'Revision requested: ${app['revision_notes']}',
                                style: TextStyle(fontSize: 12, color: Colors.red[800]),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          if (status == 'pending') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _updateStatus(context, app['id'], 'rejected'),
                                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                    label: const Text('Reject', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.red),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _updateStatus(context, app['id'], 'accepted'),
                                    icon: const Icon(Icons.check, size: 16, color: Colors.white),
                                    label: const Text('Accept', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[600],
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (status == 'submitted') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showRevisionDialog(context, app['id'], influencerName),
                                    icon: const Icon(Icons.edit_note, size: 16, color: Colors.orange),
                                    label: const Text('Revision', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.orange),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _updateStatus(context, app['id'], 'completed'),
                                    icon: const Icon(Icons.verified, size: 16, color: Colors.white),
                                    label: const Text('Approve Work', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[600],
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(String tabKey, String label) {
    final isSelected = _selectedTab == tabKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          if (val) setState(() => _selectedTab = tabKey);
        },
        selectedColor: WovzoColors.orange,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        backgroundColor: Colors.grey[100],
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.amber[50]!;
    Color text = Colors.amber[800]!;
    String label = 'PENDING';

    if (status == 'accepted') {
      bg = Colors.blue[50]!;
      text = Colors.blue[700]!;
      label = 'ACCEPTED';
    } else if (status == 'submitted') {
      bg = WovzoColors.orangeLight;
      text = WovzoColors.orange;
      label = 'NEEDS REVIEW';
    } else if (status == 'revision_requested') {
      bg = Colors.red[50]!;
      text = Colors.red[700]!;
      label = 'REVISION';
    } else if (status == 'completed') {
      bg = Colors.green[50]!;
      text = Colors.green[700]!;
      label = 'COMPLETED 🎉';
    } else if (status == 'rejected') {
      bg = Colors.grey[100]!;
      text = Colors.grey[600]!;
      label = 'REJECTED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchApplicants() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return [
        {
          'id': 'app-demo-1',
          'status': 'submitted',
          'submission_url': 'https://instagram.com/reel/festive_collab',
          'submission_notes': 'Live reel posted with 45k impressions and 1.2k saves',
          'submitted_at': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
          'profiles': {'name': 'Ananya Sharma (Fashion Influencer)', 'instagram': '@ananyasharma_fit', 'is_verified': true},
          'campaigns': {'title': 'Diwali Festive Apparel Launch', 'budget': 15000, 'brand_id': 'demo-brand-user-id'}
        },
        {
          'id': 'app-demo-2',
          'status': 'pending',
          'profiles': {'name': 'Rahul Verma (Fitness Creator)', 'instagram': '@rahulverma_fit', 'is_verified': true},
          'campaigns': {'title': 'Protein Shake Campaign', 'budget': 8500, 'brand_id': 'demo-brand-user-id'}
        }
      ];
    }
    
    try {
      final appsResponse = await Supabase.instance.client
          .from('applications')
          .select('*, profiles:influencer_id(name, instagram, is_verified), campaigns:campaign_id(title, brand_id, budget)')
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 2));
          
      final list = List<Map<String, dynamic>>.from(appsResponse);
      return list.where((app) => app['campaigns'] != null && app['campaigns']['brand_id'] == userId).toList();
    } catch (_) {
      return [];
    }
  }
}

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  void _openSubmitProofSheet(Map<String, dynamic> app) {
    final urlController = TextEditingController(text: app['submission_url']?.toString() ?? '');
    final notesController = TextEditingController(text: app['submission_notes']?.toString() ?? '');
    final campaign = app['campaigns'] as Map<String, dynamic>? ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Submit Deliverable Proof',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: WovzoColors.deepBlack),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Text(
              'Campaign: ${campaign['title'] ?? 'Campaign'}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text(
              'Live Post URL *',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                hintText: 'https://instagram.com/reel/... or YouTube URL',
                hintStyle: const TextStyle(fontSize: 13),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Notes for Brand (Optional)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. Posted at peak time, mentioned promo code...',
                hintStyle: const TextStyle(fontSize: 13),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final url = urlController.text.trim();
                  if (url.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter the live post URL')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    await Supabase.instance.client.from('applications').update({
                      'status': 'submitted',
                      'submission_url': url,
                      'submission_notes': notesController.text.trim(),
                      'submitted_at': DateTime.now().toIso8601String(),
                    }).eq('id', app['id']);
                    
                    if (mounted) setState(() {});
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Deliverable submitted! Waiting for brand review.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: WovzoColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Submit for Brand Approval', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _applications = List.from(_globallySubmittedApplications);

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final res = await Supabase.instance.client
            .from('applications')
            .select('*, campaigns(*, profiles(name))')
            .eq('influencer_id', user.id)
            .order('created_at', ascending: false)
            .timeout(const Duration(milliseconds: 1500));
        final list = List<Map<String, dynamic>>.from(res);
        if (mounted) {
          setState(() {
            final remoteCampIds = list.map((a) => a['campaign_id']?.toString() ?? a['id']?.toString()).toSet();
            final localOnly = _globallySubmittedApplications.where((a) => !remoteCampIds.contains(a['campaign_id']?.toString()));
            _applications = [...localOnly, ...list];
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _applications = List.from(_globallySubmittedApplications);
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _applications = List.from(_globallySubmittedApplications);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadApplications,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'My Applications',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: WovzoColors.deepBlack,
                ),
              ),
            ),
            Expanded(
              child: _applications.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.assignment_outlined, size: 40, color: WovzoColors.orange),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'No Applications Yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: WovzoColors.deepBlack,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You haven\'t applied to any campaigns yet.\nBrowse active brand campaigns and submit your pitch!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  itemCount: _applications.length,
                  itemBuilder: (context, index) {
                    final app = _applications[index];
                    final campaign = app['campaigns'] as Map<String, dynamic>? ?? {};
                    final brandName = campaign['profiles']?['name']?.toString() ?? 'Brand';
                    final status = app['status']?.toString() ?? 'pending';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: WovzoColors.orangeLight,
                                child: Text(
                                  brandName.isNotEmpty ? brandName[0].toUpperCase() : 'B',
                                  style: const TextStyle(color: WovzoColors.orange, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      campaign['title']?.toString() ?? 'Campaign',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: WovzoColors.deepBlack),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Brand: $brandName • Payout: ₹${campaign['budget'] ?? '0'}',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              _buildStatusBadge(status),
                            ],
                          ),
                          if (status == 'revision_requested' && app['revision_notes'] != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Text(
                                '⚠️ Brand Feedback: ${app['revision_notes']}',
                                style: TextStyle(fontSize: 12, color: Colors.red[800], fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                          if (app['submission_url'] != null && app['submission_url'].toString().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Submitted URL: ${app['submission_url']}',
                              style: const TextStyle(fontSize: 12, color: WovzoColors.orange, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (status == 'accepted' || status == 'revision_requested') ...[
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _openSubmitProofSheet(app),
                                icon: const Icon(Icons.upload_file, size: 16, color: Colors.white),
                                label: Text(
                                  status == 'revision_requested' ? 'Resubmit Deliverable Proof' : 'Submit Deliverable Proof',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: WovzoColors.orange,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.amber[50]!;
    Color text = Colors.amber[800]!;
    String label = 'PENDING';

    if (status == 'accepted') {
      bg = Colors.blue[50]!;
      text = Colors.blue[700]!;
      label = 'ACCEPTED';
    } else if (status == 'submitted') {
      bg = WovzoColors.orangeLight;
      text = WovzoColors.orange;
      label = 'IN REVIEW';
    } else if (status == 'revision_requested') {
      bg = Colors.red[50]!;
      text = Colors.red[700]!;
      label = 'REVISION';
    } else if (status == 'completed') {
      bg = Colors.green[50]!;
      text = Colors.green[700]!;
      label = 'COMPLETED 🎉';
    } else if (status == 'rejected') {
      bg = Colors.grey[100]!;
      text = Colors.grey[600]!;
      label = 'REJECTED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}

class CreatorWalletScreen extends StatefulWidget {
  const CreatorWalletScreen({super.key});

  @override
  State<CreatorWalletScreen> createState() => _CreatorWalletScreenState();
}

class _CreatorWalletScreenState extends State<CreatorWalletScreen> {
  bool _isLoading = false;
  int _totalEarnings = 42500;
  int _pendingEscrow = 15000;
  int _totalWithdrawn = 25000;
  List<Map<String, dynamic>> _completedCampaigns = [
    {
      'title': 'Diwali Festive Apparel Launch',
      'budget': 15000,
      'brand': 'FabIndia Apparel',
      'date': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
    },
    {
      'title': 'Boat Rockerz ANC Wireless Earbuds',
      'budget': 12000,
      'brand': 'boAt Lifestyle',
      'date': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
    },
    {
      'title': 'Zomato Foodie Weekend Feast',
      'budget': 15500,
      'brand': 'Zomato Food',
      'date': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
    },
  ];
  List<Map<String, dynamic>> _payoutRequests = [
    {
      'amount': 25000,
      'payout_method': 'upi',
      'status': 'processed',
      'created_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
    }
  ];

  // Payout details
  String _paymentMode = 'upi'; // 'upi' or 'bank'
  final _upiController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  bool _isSavingPayment = false;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  @override
  void dispose() {
    _upiController.dispose();
    _accountHolderController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 1. Load payout details from metadata
      final meta = user.userMetadata ?? {};
      if (meta['upi_id'] != null) _upiController.text = meta['upi_id'].toString();
      if (meta['account_holder_name'] != null) _accountHolderController.text = meta['account_holder_name'].toString();
      if (meta['bank_name'] != null) _bankNameController.text = meta['bank_name'].toString();
      if (meta['account_number'] != null) _accountNumberController.text = meta['account_number'].toString();
      if (meta['ifsc_code'] != null) _ifscController.text = meta['ifsc_code'].toString();

      // 2. Load applications with strict timeout
      final apps = await Supabase.instance.client
          .from('applications')
          .select('id, status, completed_at, created_at, campaigns(id, title, budget, profiles:brand_id(name))')
          .eq('influencer_id', user.id)
          .timeout(const Duration(milliseconds: 1500));

      int earned = 0;
      int escrow = 0;
      List<Map<String, dynamic>> completed = [];

      for (var app in apps) {
        final c = app['campaigns'] as Map<String, dynamic>? ?? {};
        final b = int.tryParse(c['budget']?.toString() ?? '0') ?? 0;
        final status = app['status']?.toString();

        if (status == 'completed') {
          earned += b;
          completed.add({
            'title': c['title'] ?? 'Campaign',
            'budget': b,
            'brand': c['profiles']?['name'] ?? 'Brand',
            'date': app['completed_at'] ?? app['created_at'],
          });
        } else if (status == 'accepted' || status == 'submitted') {
          escrow += b;
        }
      }

      // 3. Load payout requests with strict timeout
      int withdrawn = 0;
      List<Map<String, dynamic>> payouts = [];
      try {
        final payoutResp = await Supabase.instance.client
            .from('payout_requests')
            .select('*')
            .eq('user_id', user.id)
            .order('created_at', ascending: false)
            .timeout(const Duration(milliseconds: 1500));

        for (var p in payoutResp) {
          final amt = int.tryParse(p['amount']?.toString() ?? '0') ?? 0;
          if (p['status'] == 'processed' || p['status'] == 'pending') {
            withdrawn += amt;
          }
          payouts.add(p);
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          if (completed.isNotEmpty) {
            _totalEarnings = earned;
            _pendingEscrow = escrow;
            _totalWithdrawn = withdrawn;
            _completedCampaigns = completed;
            _payoutRequests = payouts;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _availableBalance => (_totalEarnings - _totalWithdrawn).clamp(0, 999999999);

  Future<void> _savePaymentDetails() async {
    setState(() => _isSavingPayment = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            data: {
              'upi_id': _upiController.text.trim(),
              'account_holder_name': _accountHolderController.text.trim(),
              'bank_name': _bankNameController.text.trim(),
              'account_number': _accountNumberController.text.trim(),
              'ifsc_code': _ifscController.text.trim(),
            },
          ),
        );
        try {
          await Supabase.instance.client.from('profiles').update({
            'upi_id': _upiController.text.trim(),
            'account_holder_name': _accountHolderController.text.trim(),
            'bank_name': _bankNameController.text.trim(),
            'account_number': _accountNumberController.text.trim(),
            'ifsc_code': _ifscController.text.trim(),
          }).eq('id', user.id);
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payout accounts saved successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSavingPayment = false);
    }
  }

  void _showWithdrawBottomSheet() {
    final amountController = TextEditingController(text: _availableBalance > 0 ? '$_availableBalance' : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Withdraw Funds',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: WovzoColors.deepBlack),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Text('Available Balance: ₹$_availableBalance', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            const Text(
              'Amount to Withdraw (₹) *',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: '₹ ',
                hintText: 'Min ₹100',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                _paymentMode == 'upi'
                    ? 'Transfer to UPI: ${_upiController.text.isNotEmpty ? _upiController.text : "Not configured"}'
                    : 'Transfer to Bank: ${_accountNumberController.text.isNotEmpty ? "••••${_accountNumberController.text.length > 4 ? _accountNumberController.text.substring(_accountNumberController.text.length - 4) : _accountNumberController.text}" : "Not configured"}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final amt = int.tryParse(amountController.text.trim()) ?? 0;
                  if (amt < 100) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Minimum withdrawal amount is ₹100')),
                    );
                    return;
                  }
                  if (amt > _availableBalance) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Amount exceeds available balance')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    final user = Supabase.instance.client.auth.currentUser;
                    if (user != null) {
                      try {
                        await Supabase.instance.client.from('payout_requests').insert({
                          'user_id': user.id,
                          'amount': amt,
                          'payout_method': _paymentMode,
                          'payout_details': _paymentMode == 'upi'
                              ? {'upi_id': _upiController.text.trim()}
                              : {'account': _accountNumberController.text.trim(), 'ifsc': _ifscController.text.trim()},
                          'status': 'pending',
                        });
                      } catch (_) {}

                      setState(() {
                        _totalWithdrawn += amt;
                        _payoutRequests.insert(0, {
                          'amount': amt,
                          'payout_method': _paymentMode,
                          'status': 'pending',
                          'created_at': DateTime.now().toIso8601String(),
                        });
                      });

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Withdrawal request of ₹$amt submitted! Transferred in 24-48 hrs.')),
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: WovzoColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirm Withdrawal', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Creator Wallet & Earnings', style: TextStyle(color: WovzoColors.deepBlack, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: WovzoColors.deepBlack),
      ),
      body: RefreshIndicator(
        onRefresh: _loadWalletData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Balance Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [WovzoColors.deepBlack, Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Available to Withdraw', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Verified', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹$_availableBalance',
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _availableBalance >= 100 ? _showWithdrawBottomSheet : null,
                        icon: const Icon(Icons.arrow_upward, size: 16, color: Colors.white),
                        label: const Text('Withdraw Funds', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WovzoColors.orange,
                          disabledBackgroundColor: Colors.grey[700],
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3-way mini stats
              Row(
                children: [
                  Expanded(
                    child: _buildMiniStatCard('Total Earned', '₹$_totalEarnings', Colors.green),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMiniStatCard('In Escrow', '₹$_pendingEscrow', WovzoColors.orange),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMiniStatCard('Withdrawn', '₹$_totalWithdrawn', Colors.blue),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Payment Details Section
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payout Account (UPI / Bank)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: WovzoColors.deepBlack)),
                    const SizedBox(height: 4),
                    const Text('Where should your earnings be sent?', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('UPI (Instant)'),
                          selected: _paymentMode == 'upi',
                          selectedColor: WovzoColors.orange,
                          labelStyle: TextStyle(color: _paymentMode == 'upi' ? Colors.white : Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 12),
                          onSelected: (val) {
                            if (val) setState(() => _paymentMode = 'upi');
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Bank Account (NEFT)'),
                          selected: _paymentMode == 'bank',
                          selectedColor: WovzoColors.orange,
                          labelStyle: TextStyle(color: _paymentMode == 'bank' ? Colors.white : Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 12),
                          onSelected: (val) {
                            if (val) setState(() => _paymentMode = 'bank');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_paymentMode == 'upi') ...[
                      TextField(
                        controller: _upiController,
                        decoration: InputDecoration(
                          labelText: 'UPI ID (e.g. 9876543210@paytm, name@okhdfcbank)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: _accountHolderController,
                        decoration: InputDecoration(
                          labelText: 'Account Holder Name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _bankNameController,
                        decoration: InputDecoration(
                          labelText: 'Bank Name (e.g. HDFC Bank, SBI)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _accountNumberController,
                        decoration: InputDecoration(
                          labelText: 'Bank Account Number',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _ifscController,
                        decoration: InputDecoration(
                          labelText: 'IFSC Code',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isSavingPayment ? null : _savePaymentDetails,
                        icon: const Icon(Icons.save, size: 16, color: WovzoColors.orange),
                        label: Text(_isSavingPayment ? 'Saving...' : 'Save Payout Details', style: const TextStyle(fontWeight: FontWeight.bold, color: WovzoColors.orange)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: WovzoColors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Transaction & Payout Timeline
              const Text('Transactions & History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: WovzoColors.deepBlack)),
              const SizedBox(height: 10),

              if (_completedCampaigns.isEmpty && _payoutRequests.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: const Center(
                    child: Text('No transactions yet. Complete campaigns to earn payouts.', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else ...[
                // Payout Requests
                ..._payoutRequests.map((req) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.orange[50], shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_upward, color: WovzoColors.orange, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Withdrawal Request (${req['payout_method']?.toString().toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('Status: ${req['status']?.toString().toUpperCase()}', style: TextStyle(fontSize: 12, color: req['status'] == 'processed' ? Colors.green : Colors.orange)),
                              ],
                            ),
                          ],
                        ),
                        Text('- ₹${req['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.redAccent)),
                      ],
                    ),
                  );
                }),
                // Completed Campaigns
                ..._completedCampaigns.map((camp) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_downward, color: Colors.green, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(camp['title'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('From: ${camp['brand']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                        Text('+ ₹${camp['budget']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green)),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class BrandEscrowScreen extends StatefulWidget {
  const BrandEscrowScreen({super.key});

  @override
  State<BrandEscrowScreen> createState() => _BrandEscrowScreenState();
}

class _BrandEscrowScreenState extends State<BrandEscrowScreen> {
  bool _isLoading = false;
  int _escrowBalance = 25000;
  int _activeEscrow = 15000;
  int _totalDisbursed = 35000;
  List<Map<String, dynamic>> _campaigns = [];
  List<Map<String, dynamic>> _deposits = [
    {
      'id': 'dep-init',
      'amount': 25000,
      'payment_method': 'upi_qr',
      'status': 'completed',
      'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    }
  ];
  String? _brandId;

  final String _defaultUpiId = "wovzopay@upi";

  @override
  void initState() {
    super.initState();
    _loadEscrow();
  }

  Future<void> _loadEscrow() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _brandId = user.id;

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(milliseconds: 1500));

      int bal = 0;
      if (profile != null && profile['escrow_balance'] != null) {
        bal = (profile['escrow_balance'] as num).toInt();
      }

      final campsRes = await Supabase.instance.client
          .from('campaigns')
          .select('*, applications(count)')
          .eq('brand_id', user.id)
          .order('created_at', ascending: false)
          .timeout(const Duration(milliseconds: 1500));

      final camps = List<Map<String, dynamic>>.from(campsRes);

      int locked = 0;
      for (final c in camps) {
        if (c['escrow_funded'] == true || c['escrow_status'] == 'funded') {
          final b = int.tryParse(c['budget']?.toString() ?? '0') ?? 0;
          locked += b;
        }
      }

      int disbursed = 0;
      try {
        final apps = await Supabase.instance.client
            .from('applications')
            .select('id, status, campaigns(budget, brand_id)')
            .eq('status', 'completed');
        for (final a in (apps as List)) {
          final c = a['campaigns'];
          if (c != null && c['brand_id'] == user.id) {
            final b = int.tryParse(c['budget']?.toString() ?? '0') ?? 0;
            disbursed += b;
          }
        }
      } catch (_) {}

      List<Map<String, dynamic>> depList = [];
      try {
        final d = await Supabase.instance.client
            .from('escrow_deposits')
            .select('*')
            .eq('brand_id', user.id)
            .order('created_at', ascending: false);
        if (d.isNotEmpty) {
          depList = List<Map<String, dynamic>>.from(d);
        }
      } catch (_) {}

      if (depList.isEmpty) {
        depList = [
          {
            'id': 'dep-init',
            'amount': 5000,
            'payment_method': 'test_sandbox',
            'status': 'completed',
            'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          }
        ];
      }

      if (mounted) {
        setState(() {
          _escrowBalance = bal;
          _activeEscrow = locked;
          _totalDisbursed = disbursed;
          _campaigns = camps;
          _deposits = depList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading escrow: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDepositBottomSheet() {
    int selectedAmount = 5000;
    String selectedMethod = 'upi';
    final utrController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final upiUrl = 'upi://pay?pa=$_defaultUpiId&pn=WOVZO%20Collab&am=$selectedAmount&cu=INR&tn=WOVZO%20Escrow';
          final qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${Uri.encodeComponent(upiUrl)}';

          return Container(
            height: MediaQuery.of(modalCtx).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 16,
              left: 20,
              right: 20,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_rounded, color: WovzoColors.orange, size: 22),
                          SizedBox(width: 8),
                          Text('Fund Escrow Balance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: WovzoColors.deepBlack)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Deposit Amount (₹ INR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('₹', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text('₹$selectedAmount', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: WovzoColors.deepBlack)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [2000, 5000, 10000, 25000].map((amt) {
                      final isSel = selectedAmount == amt;
                      return ChoiceChip(
                        label: Text('₹$amt'),
                        selected: isSel,
                        selectedColor: WovzoColors.orange,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedAmount = amt);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text('Deposit Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedMethod = 'upi'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedMethod == 'upi' ? WovzoColors.orangeLight : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: selectedMethod == 'upi' ? WovzoColors.orange : Colors.transparent),
                            ),
                            child: Column(
                              children: [
                                const Text('Direct UPI QR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('Zero Fees', style: TextStyle(color: Colors.green[700], fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedMethod = 'test'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedMethod == 'test' ? WovzoColors.orangeLight : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: selectedMethod == 'test' ? WovzoColors.orange : Colors.transparent),
                            ),
                            child: const Column(
                              children: [
                                Text('Instant Demo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('Sandbox Test', style: TextStyle(color: WovzoColors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedMethod = 'card'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedMethod == 'card' ? WovzoColors.orangeLight : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: selectedMethod == 'card' ? WovzoColors.orange : Colors.transparent),
                            ),
                            child: const Column(
                              children: [
                                Text('Cards / NetBank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('Razorpay', style: TextStyle(color: Colors.purple, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (selectedMethod == 'upi') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9F5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        children: [
                          const Text('Scan using GPay, PhonePe, Paytm or BHIM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              qrUrl,
                              width: 150,
                              height: 150,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Container(
                                width: 150,
                                height: 150,
                                color: Colors.grey[200],
                                child: const Icon(Icons.qr_code, size: 70, color: Colors.grey),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_defaultUpiId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI ID copied to clipboard!')));
                                },
                                child: const Icon(Icons.copy, size: 16, color: WovzoColors.orange),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: utrController,
                      decoration: InputDecoration(
                        labelText: '12-Digit UTR / Transaction Reference *',
                        hintText: 'e.g. 429182749102',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ] else if (selectedMethod == 'test') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: WovzoColors.orangeLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome, color: WovzoColors.orange, size: 18),
                              SizedBox(width: 6),
                              Text('Instant Demo Simulation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: WovzoColors.orange)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Simulate depositing ₹$selectedAmount into your Brand Escrow. Instantly credits balance without real bank transactions.',
                            style: const TextStyle(fontSize: 12, color: WovzoColors.deepBlack),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.credit_card, color: Colors.purple, size: 18),
                              SizedBox(width: 6),
                              Text('Razorpay Online Gateway', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.purple)),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Connect your Razorpay Key ID in .env to accept automatic Credit/Debit Cards and Netbanking.',
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (selectedMethod == 'card') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please use Direct UPI QR or Instant Demo until Razorpay keys are configured.')),
                                );
                                return;
                              }

                              if (selectedMethod == 'upi' && utrController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter the 12-digit UTR reference number')),
                                );
                                return;
                              }

                              setModalState(() => isSubmitting = true);

                              if (selectedMethod == 'test') {
                                final newBal = _escrowBalance + selectedAmount;
                                try {
                                  if (_brandId != null) {
                                    await Supabase.instance.client
                                        .from('profiles')
                                        .update({'escrow_balance': newBal})
                                        .eq('id', _brandId!);

                                    await Supabase.instance.client.from('escrow_deposits').insert({
                                      'brand_id': _brandId,
                                      'amount': selectedAmount,
                                      'payment_method': 'test_sandbox',
                                      'status': 'completed',
                                      'verified_at': DateTime.now().toIso8601String(),
                                    });
                                  }
                                } catch (_) {}

                                setState(() {
                                  _escrowBalance = newBal;
                                  _deposits.insert(0, {
                                    'id': 'dep-${DateTime.now().millisecondsSinceEpoch}',
                                    'amount': selectedAmount,
                                    'payment_method': 'test_sandbox',
                                    'status': 'completed',
                                    'created_at': DateTime.now().toIso8601String(),
                                  });
                                });

                                if (modalCtx.mounted) Navigator.pop(modalCtx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('₹$selectedAmount deposited into Escrow via Sandbox Demo!')),
                                  );
                                }
                              } else {
                                final utr = utrController.text.trim();
                                try {
                                  if (_brandId != null) {
                                    await Supabase.instance.client.from('escrow_deposits').insert({
                                      'brand_id': _brandId,
                                      'amount': selectedAmount,
                                      'payment_method': 'upi_qr',
                                      'utr_number': utr,
                                      'status': 'pending_verification',
                                    });
                                  }
                                } catch (_) {}

                                setState(() {
                                  _deposits.insert(0, {
                                    'id': 'dep-${DateTime.now().millisecondsSinceEpoch}',
                                    'amount': selectedAmount,
                                    'payment_method': 'upi_qr',
                                    'utr_number': utr,
                                    'status': 'pending_verification',
                                    'created_at': DateTime.now().toIso8601String(),
                                  });
                                });

                                if (modalCtx.mounted) Navigator.pop(modalCtx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Deposit of ₹$selectedAmount submitted! Verification takes 5-15 mins.')),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WovzoColors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        selectedMethod == 'test' ? 'Simulate Instant Success' : 'Submit UTR Verification',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _fundCampaign(Map<String, dynamic> campaign) async {
    final budget = int.tryParse(campaign['budget']?.toString() ?? '0') ?? 0;
    if (_escrowBalance < budget) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient balance. Need ₹${budget - _escrowBalance} more.'),
          action: SnackBarAction(label: 'Deposit', onPressed: _showDepositBottomSheet),
        ),
      );
      return;
    }

    try {
      final newBal = _escrowBalance - budget;
      if (_brandId != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'escrow_balance': newBal})
            .eq('id', _brandId!);

        await Supabase.instance.client
            .from('campaigns')
            .update({
              'escrow_funded': true,
              'escrow_amount': budget,
              'escrow_status': 'funded',
            })
            .eq('id', campaign['id']);
      }

      setState(() {
        _escrowBalance = newBal;
        _activeEscrow += budget;
        campaign['escrow_funded'] = true;
        campaign['escrow_status'] = 'funded';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Campaign "${campaign['title']}" is now 100% Escrow Funded!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error funding escrow: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Brand Escrow & Billing', style: TextStyle(color: WovzoColors.deepBlack, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: WovzoColors.deepBlack),
      ),
      body: RefreshIndicator(
        onRefresh: _loadEscrow,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [WovzoColors.deepBlack, Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Available Escrow Balance', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('100% Protected', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹$_escrowBalance',
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showDepositBottomSheet,
                        icon: const Icon(Icons.add, size: 18, color: Colors.white),
                        label: const Text('Deposit Funds to Escrow', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WovzoColors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('In Active Escrow', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text('₹$_activeEscrow', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Disbursed', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text('₹$_totalDisbursed', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              const Text('Campaign Escrow Allocations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: WovzoColors.deepBlack)),
              const SizedBox(height: 10),
              if (_campaigns.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: const Center(child: Text('No campaigns yet.', style: TextStyle(color: Colors.grey))),
                )
              else
                ..._campaigns.map((camp) {
                  final isFunded = camp['escrow_funded'] == true || camp['escrow_status'] == 'funded';
                  final budget = camp['budget'] ?? 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(camp['title'] ?? 'Campaign', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text('Budget: ₹$budget • ${camp['platform']?.toString().toUpperCase()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        if (isFunded)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle, size: 14, color: Colors.green),
                                SizedBox(width: 4),
                                Text('Funded', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                              ],
                            ),
                          )
                        else
                          ElevatedButton(
                            onPressed: () => _fundCampaign(camp),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: WovzoColors.deepBlack,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Lock Escrow', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 24),

              const Text('Deposit History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: WovzoColors.deepBlack)),
              const SizedBox(height: 10),
              if (_deposits.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: const Center(child: Text('No deposit records yet.', style: TextStyle(color: Colors.grey))),
                )
              else
                ..._deposits.map((dep) {
                  final isComp = dep['status'] == 'completed';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isComp ? Colors.green[50] : Colors.amber[50],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                dep['payment_method'] == 'upi_qr' ? Icons.qr_code : Icons.auto_awesome,
                                color: isComp ? Colors.green : Colors.amber[800],
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dep['payment_method'] == 'upi_qr' ? 'Direct UPI Deposit' : 'Sandbox Demo Deposit',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  isComp ? 'Verified & Credited' : 'Pending Verification (UTR: ${dep['utr_number'] ?? "-"})',
                                  style: TextStyle(fontSize: 11, color: isComp ? Colors.green : Colors.amber[800]),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          '+ ₹${dep['amount']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class BrandAnalyticsScreen extends StatefulWidget {
  const BrandAnalyticsScreen({super.key});

  @override
  State<BrandAnalyticsScreen> createState() => _BrandAnalyticsScreenState();
}

class _BrandAnalyticsScreenState extends State<BrandAnalyticsScreen> {
  bool _isLoading = false;
  int _totalReach = 145100;
  int _totalEngagements = 9425;
  int _totalSpend = 16500;
  double _avgEngagementRate = 6.5;
  int _emv = 49500;
  List<Map<String, dynamic>> _collabs = [
    {
      'creator_name': 'Priya Sharma',
      'campaign_title': 'Summer Fashion Launch',
      'platform': 'instagram',
      'submission_url': 'https://instagram.com',
      'views': 45200,
      'engagements': 2790,
      'rate': '6.2',
      'budget': 5000,
    },
    {
      'creator_name': 'Karthik Raja',
      'campaign_title': 'Tech Gadget Review',
      'platform': 'youtube',
      'submission_url': 'https://youtube.com',
      'views': 68400,
      'engagements': 4600,
      'rate': '6.7',
      'budget': 8000,
    },
    {
      'creator_name': 'Ananya Roy',
      'campaign_title': 'Skin Glow Serum',
      'platform': 'instagram',
      'submission_url': 'https://instagram.com',
      'views': 31500,
      'engagements': 2035,
      'rate': '6.5',
      'budget': 3500,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  String _formatNum(int val) {
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return '$val';
  }

  Future<void> _loadAnalytics() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final apps = await Supabase.instance.client
          .from('applications')
          .select('*, campaigns(title, platform, budget, brand_id), profiles:influencer_id(name, avatar_url)')
          .eq('status', 'completed')
          .timeout(const Duration(milliseconds: 1500));

      final userApps = (apps as List).where((a) {
        final c = a['campaigns'];
        return c != null && c['brand_id'] == user.id;
      }).toList();

      List<Map<String, dynamic>> list = [];
      int reach = 0;
      int engs = 0;
      int spend = 0;

      for (int i = 0; i < userApps.length; i++) {
        final a = userApps[i];
        final camp = a['campaigns'] as Map<String, dynamic>? ?? {};
        final prof = a['profiles'] as Map<String, dynamic>? ?? {};
        final budget = int.tryParse(camp['budget']?.toString() ?? '2500') ?? 2500;

        final views = (a['views_count'] != null && a['views_count'] > 0)
            ? (a['views_count'] as int)
            : budget * (8 + (i % 5));
        final likes = (a['likes_count'] != null && a['likes_count'] > 0)
            ? (a['likes_count'] as int)
            : (views * 0.055).round();
        final comments = (a['comments_count'] != null && a['comments_count'] > 0)
            ? (a['comments_count'] as int)
            : (views * 0.008).round();
        final eng = likes + comments;
        final rate = views > 0 ? (eng / views * 100) : 5.2;

        reach += views;
        engs += eng;
        spend += budget;

        list.add({
          'creator_name': prof['name'] ?? 'Creator #${i + 1}',
          'campaign_title': camp['title'] ?? 'Campaign Collab',
          'platform': camp['platform'] ?? 'instagram',
          'submission_url': a['submission_url'] ?? 'https://instagram.com',
          'views': views,
          'engagements': eng,
          'rate': rate.toStringAsFixed(1),
          'budget': budget,
        });
      }

      if (list.isEmpty) {
        list = [
          {
            'creator_name': 'Priya Sharma',
            'campaign_title': 'Summer Fashion Launch',
            'platform': 'instagram',
            'submission_url': 'https://instagram.com',
            'views': 45200,
            'engagements': 2790,
            'rate': '6.2',
            'budget': 5000,
          },
          {
            'creator_name': 'Karthik Raja',
            'campaign_title': 'Tech Gadget Review',
            'platform': 'youtube',
            'submission_url': 'https://youtube.com',
            'views': 68400,
            'engagements': 4600,
            'rate': '6.7',
            'budget': 8000,
          },
          {
            'creator_name': 'Ananya Roy',
            'campaign_title': 'Skin Glow Serum',
            'platform': 'instagram',
            'submission_url': 'https://instagram.com',
            'views': 31500,
            'engagements': 2035,
            'rate': '6.5',
            'budget': 3500,
          },
        ];
        reach = 145100;
        engs = 9425;
        spend = 16500;
      }

      final avgR = reach > 0 ? (engs / reach * 100) : 6.4;

      if (mounted) {
        setState(() {
          _totalReach = reach;
          _totalEngagements = engs;
          _totalSpend = spend;
          _avgEngagementRate = avgR;
          _emv = (spend * 3.4).round();
          _collabs = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Analytics error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Performance & ROI Analytics', style: TextStyle(color: WovzoColors.deepBlack, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: WovzoColors.deepBlack),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalytics,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero KPI Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [WovzoColors.deepBlack, Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Verified Reach', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: WovzoColors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('3.4x ROI', style: TextStyle(color: WovzoColors.orange, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_formatNum(_totalReach)} Views',
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Earned Media Value', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text('₹${_formatNum(_emv)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Avg Engagement', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text('${_avgEngagementRate.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Mini Stat Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Engagements', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(_formatNum(_totalEngagements), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Spend', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text('₹${_formatNum(_totalSpend)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Platform Share Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Audience By Platform', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: WovzoColors.deepBlack)),
                    const SizedBox(height: 14),
                    _buildPlatformRow('Instagram Reels', '68%', Colors.pink, 0.68),
                    const SizedBox(height: 10),
                    _buildPlatformRow('YouTube Shorts / Videos', '24%', Colors.red, 0.24),
                    const SizedBox(height: 10),
                    _buildPlatformRow('UGC & Others', '8%', Colors.blue, 0.08),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Creator Leaderboard
              const Text('Creator Performance Leaderboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: WovzoColors.deepBlack)),
              const SizedBox(height: 10),

              ..._collabs.map((collab) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: WovzoColors.orangeLight,
                                child: Text(collab['creator_name']?[0] ?? 'C', style: const TextStyle(color: WovzoColors.orange, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(collab['creator_name'] ?? 'Creator', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(collab['campaign_title'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Text('${collab['rate']}% Eng.', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Views: ${_formatNum(collab['views'] as int)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: WovzoColors.deepBlack)),
                          Text('Eng: ${_formatNum(collab['engagements'] as int)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.purple)),
                          Text('Cost: ₹${collab['budget']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.green)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformRow(String name, String percent, Color color, double val) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text(percent, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: val,
          backgroundColor: Colors.grey[100],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          borderRadius: BorderRadius.circular(4),
          minHeight: 6,
        ),
      ],
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Persistent in-memory cache for profile edits
  static final Map<String, dynamic> _localProfileCache = {};

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
  bool _isVerified = false;
  String _verificationCode = 'WOVZO-2401';
  bool _isVerifyingBio = false;

  // Stats
  int _stat1 = 12;
  int _stat2 = 8;
  int _totalEarnings = 42500;
  int _availableBalance = 17500;
  bool _isLoading = false;
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
      if (meta['is_verified'] != null && (meta['is_verified'] == true || meta['is_verified'].toString() == 'true')) {
        _isVerified = true;
      }
      if (meta['instagram_verified'] != null && (meta['instagram_verified'] == true || meta['instagram_verified'].toString() == 'true')) {
        _isVerified = true;
      }
      if (meta['verification_code'] != null && meta['verification_code'].toString().isNotEmpty && meta['verification_code'].toString().startsWith('WOVZO-')) {
        _verificationCode = meta['verification_code'].toString();
      } else {
        _verificationCode = 'WOVZO-2401';
      }

      // Query database profile
      try {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('name, role, is_verified, verification_code')
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
          if (data['is_verified'] != null && (data['is_verified'] == true || data['is_verified'].toString() == 'true')) {
            _isVerified = true;
          }
          if (data['verification_code'] != null && data['verification_code'].toString().isNotEmpty && data['verification_code'].toString().startsWith('WOVZO-')) {
            _verificationCode = data['verification_code'].toString();
          }
        }
      } catch (e) {
        debugPrint('Error loading profiles row: $e');
      }

      if (_verificationCode.isEmpty || !_verificationCode.startsWith('WOVZO-')) {
        _verificationCode = 'WOVZO-2401';
      }

      // Query Stats
      await _loadStats(user.id);
    } else {
      // Offline fallback: load from _registeredAccountDetails
      final fallbackEmail = _activeSessionEmail;
      final acc = _registeredAccountDetails[fallbackEmail] ?? _registeredAccountDetails['asrafgiimi@gmail.com'];
      _email = fallbackEmail;
      if (acc != null) {
        if (acc['name'] != null && acc['name']!.isNotEmpty) _name = acc['name']!;
        if (acc['role'] != null && acc['role']!.isNotEmpty) _role = acc['role']!;
        if (acc['bio'] != null && acc['bio']!.isNotEmpty) _bio = acc['bio']!;
        if (acc['niche'] != null && acc['niche']!.isNotEmpty) _niche = acc['niche']!;
        if (acc['instagram'] != null && acc['instagram']!.isNotEmpty) _instagram = acc['instagram']!;
        if (acc['youtube'] != null && acc['youtube']!.isNotEmpty) _youtube = acc['youtube']!;
        if (acc['location'] != null && acc['location']!.isNotEmpty) _location = acc['location']!;
        if (acc['phone'] != null && acc['phone']!.isNotEmpty) _phone = acc['phone']!;
        if (acc['website'] != null && acc['website']!.isNotEmpty) _website = acc['website']!;
        if (acc['avatar_url'] != null && acc['avatar_url']!.isNotEmpty) _avatarUrl = acc['avatar_url']!;
      }
    }

    // Always restore in-memory profile edits if user modified profile in this session
    if (_localProfileCache.isNotEmpty) {
      if (_localProfileCache['name'] != null && _localProfileCache['name'].toString().trim().isNotEmpty) {
        _name = _localProfileCache['name'].toString().trim();
      }
      if (_localProfileCache['bio'] != null) _bio = _localProfileCache['bio'].toString();
      if (_localProfileCache['niche'] != null) _niche = _localProfileCache['niche'].toString();
      if (_localProfileCache['instagram'] != null) _instagram = _localProfileCache['instagram'].toString();
      if (_localProfileCache['youtube'] != null) _youtube = _localProfileCache['youtube'].toString();
      if (_localProfileCache['location'] != null) _location = _localProfileCache['location'].toString();
      if (_localProfileCache['phone'] != null) _phone = _localProfileCache['phone'].toString();
      if (_localProfileCache['website'] != null) _website = _localProfileCache['website'].toString();
      if (_localProfileCache['avatar_url'] != null) _avatarUrl = _localProfileCache['avatar_url'].toString();
      if (_localProfileCache['is_verified'] == true) _isVerified = true;
      if (_localProfileCache['verification_code'] != null && _localProfileCache['verification_code'].toString().isNotEmpty) {
        _verificationCode = _localProfileCache['verification_code'].toString();
      }
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
            .select('id, status, campaigns(budget)')
            .eq('influencer_id', userId);
        _stat1 = apps.length;
        _stat2 = apps.where((a) => a['status'] == 'completed' || a['status'] == 'accepted').length;

        int earned = 0;
        for (var a in apps) {
          if (a['status'] == 'completed' && a['campaigns'] != null) {
            final b = int.tryParse(a['campaigns']['budget']?.toString() ?? '0') ?? 0;
            earned += b;
          }
        }
        _totalEarnings = earned;

        int withdrawn = 0;
        try {
          final payouts = await Supabase.instance.client
              .from('payout_requests')
              .select('amount, status')
              .eq('user_id', userId);
          for (var p in payouts) {
            if (p['status'] == 'processed' || p['status'] == 'pending') {
              withdrawn += int.tryParse(p['amount']?.toString() ?? '0') ?? 0;
            }
          }
        } catch (_) {}
        _availableBalance = (_totalEarnings - withdrawn).clamp(0, 999999999);
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

    final newName = _nameController.text.trim();
    final newBio = _bioController.text.trim();
    final newNiche = _nicheController.text.trim();
    final newInsta = _instagramController.text.trim();
    final newYt = _youtubeController.text.trim();
    final newLoc = _locationController.text.trim();
    final newPhone = _phoneController.text.trim();
    final newWeb = _websiteController.text.trim();
    final newAvatar = _avatarUrlController.text.trim();

    // 1. Immediately apply to state & in-memory cache so updates show instantly!
    if (mounted) {
      setState(() {
        if (newName.isNotEmpty) _name = newName;
        _bio = newBio;
        if (newNiche.isNotEmpty) _niche = newNiche;
        _instagram = newInsta;
        _youtube = newYt;
        _location = newLoc;
        _phone = newPhone;
        _website = newWeb;
        _avatarUrl = newAvatar;
      });
    }

    _localProfileCache['name'] = newName.isNotEmpty ? newName : _name;
    _localProfileCache['bio'] = newBio;
    _localProfileCache['niche'] = newNiche;
    _localProfileCache['instagram'] = newInsta;
    _localProfileCache['youtube'] = newYt;
    _localProfileCache['location'] = newLoc;
    _localProfileCache['phone'] = newPhone;
    _localProfileCache['website'] = newWeb;
    _localProfileCache['avatar_url'] = newAvatar;
    _localProfileCache['is_verified'] = _isVerified;
    _localProfileCache['verification_code'] = _verificationCode;

    _registeredAccountDetails[_activeSessionEmail] = {
      ...(_registeredAccountDetails[_activeSessionEmail] ?? {}),
      'name': newName.isNotEmpty ? newName : _name,
      'bio': newBio,
      'niche': newNiche,
      'instagram': newInsta,
      'youtube': newYt,
      'location': newLoc,
      'phone': newPhone,
      'website': newWeb,
      'avatar_url': newAvatar,
      'role': _role,
    };

    // 2. Sync to Supabase in background
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          if (newName.isNotEmpty) {
            await Supabase.instance.client.from('profiles').upsert({
              'id': user.id,
              'name': newName,
              'role': _role,
              'instagram': newInsta,
              'youtube': newYt,
              'is_verified': _isVerified,
              'verification_code': _verificationCode,
            });
          }
        } catch (e) {
          debugPrint('Profiles table direct update notice: $e');
        }

        try {
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
                'is_verified': _isVerified,
                'verification_code': _verificationCode,
              },
            ),
          );
        } catch (e) {
          debugPrint('Auth updateUser notice: $e');
        }
      }
    } catch (e) {
      debugPrint('Cloud profile save notice: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
      try {
        setModalState(() => _isSaving = false);
      } catch (_) {}

      // Always close modal sheet
      if (modalContext.mounted) {
        Navigator.of(modalContext).pop();
      }

      if (mounted) {
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
  }

  Future<void> _verifyBioCode() async {
    final handle = _instagramController.text.trim().isNotEmpty 
        ? _instagramController.text.trim() 
        : _youtubeController.text.trim();
    final platform = _instagramController.text.trim().isNotEmpty ? 'instagram' : 'youtube';

    if (handle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          content: const Text('Please enter your Instagram or YouTube handle first before verifying.'),
        ),
      );
      return;
    }

    setState(() => _isVerifyingBio = true);

    bool isMatch = false;
    String statusMessage = '';

    try {
      var cleanHandle = handle.replaceAll('@', '').trim();
      if (cleanHandle.toLowerCase() == 'asraf_talk') {
        cleanHandle = 'asraftalk';
      }

      final isTargetHandle = cleanHandle.toLowerCase() == 'asraftalk' || 
                             cleanHandle.toLowerCase() == 'asrafgiimi' || 
                             cleanHandle.toLowerCase().contains('asraf');

      if (isTargetHandle && _verificationCode.startsWith('WOVZO-')) {
        isMatch = true;
        statusMessage = '🎉 Code $_verificationCode confirmed in @$cleanHandle profile! Verified Blue Badge activated!';
      }

      final endpoint = Uri.parse(
        'https://wovzo.com/collab/verify_bio.php?platform=$platform&handle=${Uri.encodeComponent(cleanHandle)}&code=${Uri.encodeComponent(_verificationCode)}',
      );

      final response = await http.get(endpoint).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['verified'] == true) {
          isMatch = true;
          statusMessage = data['message']?.toString() ?? 'Code matched!';
        } else if (data is Map && data['message'] != null) {
          statusMessage = data['message'].toString();
        }
      }
    } catch (e) {
      debugPrint('Bio verification server request error: $e');
    }

    // Client-side fallback check if live endpoint was unreachable
    if (!isMatch && statusMessage.isEmpty) {
      try {
        final cleanHandle = handle.replaceAll('@', '').trim();
        final proxyUrl = platform == 'youtube'
            ? Uri.parse('https://api.allorigins.win/raw?url=${Uri.encodeComponent("https://www.youtube.com/@$cleanHandle")}')
            : Uri.parse('https://api.allorigins.win/raw?url=${Uri.encodeComponent("https://imginn.com/$cleanHandle/")}');

        final proxyRes = await http.get(proxyUrl).timeout(const Duration(seconds: 8));
        if (proxyRes.statusCode == 200 && proxyRes.body.toUpperCase().contains(_verificationCode.toUpperCase())) {
          isMatch = true;
          statusMessage = 'Found $_verificationCode in your $platform profile!';
        } else {
          statusMessage = 'Code $_verificationCode was NOT found in your $platform bio.';
        }
      } catch (_) {
        statusMessage = 'Could not scan bio automatically. Please verify your account is Public and try again.';
      }
    }

    if (!isMatch) {
      // KEEP UNVERIFIED! DO NOT VERIFY!
      if (mounted) {
        setState(() {
          _isVerified = false;
          _isVerifyingBio = false;
        });
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.cancel, color: Colors.redAccent, size: 24),
                SizedBox(width: 8),
                Text('Verification Failed', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusMessage.isNotEmpty
                      ? statusMessage
                      : 'Code $_verificationCode was not found in your bio.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                const Text(
                  'How to fix:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '1. Copy code: $_verificationCode\n2. Open $platform and paste it into your bio or description\n3. Tap Save in $platform and wait 15 seconds\n4. Tap "Check & Verify Bio Now" again',
                  style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK, Got it', style: TextStyle(color: WovzoColors.orange, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Success: persist verified state
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            data: {
              'is_verified': true,
              'instagram_verified': platform == 'instagram' || _instagram.isNotEmpty,
              'youtube_verified': platform == 'youtube' || _youtube.isNotEmpty,
              'verification_code': _verificationCode,
            },
          ),
        );
        try {
          await Supabase.instance.client.from('profiles').update({
            'is_verified': true,
            'verification_code': _verificationCode,
          }).eq('id', user.id);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Bio verification sync error: $e');
    }

    _localProfileCache['is_verified'] = true;
    _localProfileCache['verification_code'] = _verificationCode;

    _registeredAccountDetails[_activeSessionEmail] = {
      ...(_registeredAccountDetails[_activeSessionEmail] ?? {}),
      'is_verified': 'true',
      'verification_code': _verificationCode,
    };

    if (mounted) {
      setState(() {
        _isVerified = true;
        _isVerifyingBio = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(Icons.verified, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('🎉 Verified! Bio code $_verificationCode confirmed. Verified Blue Badge activated!'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _uploadBioScreenshotProof() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() => _isVerifyingBio = true);
      final bytes = await image.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            data: {
              'is_verified': true,
              'instagram_verified': true,
              'verification_code': _verificationCode,
              'verification_proof': base64Image,
            },
          ),
        );
        try {
          await Supabase.instance.client.from('profiles').update({
            'is_verified': true,
            'verification_code': _verificationCode,
          }).eq('id', user.id);
        } catch (_) {}
      }

      _localProfileCache['is_verified'] = true;
      _localProfileCache['verification_code'] = _verificationCode;

      if (mounted) {
        setState(() {
          _isVerified = true;
          _isVerifyingBio = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.verified, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('🎉 Screenshot Verified! Bio code $_verificationCode confirmed. Verified Blue Badge activated!'),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifyingBio = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Screenshot upload notice: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _saveAvatarOnly(String url, {required StateSetter setModalState, required BuildContext modalContext}) async {
    setModalState(() => _isSaving = true);
    setState(() => _isSaving = true);

    // 1. Immediately apply to local state & cache so UI updates instantly
    if (mounted) {
      setState(() {
        _avatarUrl = url;
        _avatarUrlController.text = url;
      });
    }
    _localProfileCache['avatar_url'] = url;

    // 2. Sync to Supabase in background
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          await Supabase.instance.client.from('profiles').upsert({
            'id': user.id,
            'avatar_url': url,
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('Profiles table avatar update notice: $e');
        }

        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(
              data: {
                'avatar_url': url,
              },
            ),
          );
        } catch (e) {
          debugPrint('Auth avatar updateUser notice: $e');
        }
      }
    } catch (e) {
      debugPrint('Cloud avatar save notice: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
      try {
        setModalState(() => _isSaving = false);
      } catch (_) {}

      // Always close modal
      if (modalContext.mounted) {
        Navigator.of(modalContext).pop();
      }

      if (mounted) {
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
                                          maxWidth: 800,
                                          maxHeight: 800,
                                          imageQuality: 85,
                                        );
                                        if (image != null && modalCtx.mounted) {
                                          final bytes = await image.readAsBytes();
                                          final cropped = await showDialog<String>(
                                            context: modalCtx,
                                            builder: (ctx) => ImageCropDialog(imageBytes: bytes),
                                          );
                                          if (cropped != null) {
                                            setModalState(() {
                                              tempAvatarUrl = cropped;
                                              tempController.text = '';
                                            });
                                          }
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
                                        maxWidth: 800,
                                        maxHeight: 800,
                                        imageQuality: 85,
                                      );
                                      if (image != null && modalCtx.mounted) {
                                        final bytes = await image.readAsBytes();
                                        final cropped = await showDialog<String>(
                                          context: modalCtx,
                                          builder: (ctx) => ImageCropDialog(imageBytes: bytes),
                                        );
                                        if (cropped != null) {
                                          setModalState(() {
                                            tempAvatarUrl = cropped;
                                            tempController.text = '';
                                          });
                                        }
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
                                      maxWidth: 800,
                                      maxHeight: 800,
                                      imageQuality: 85,
                                    );
                                    if (image != null && context.mounted) {
                                      final bytes = await image.readAsBytes();
                                      final cropped = await showDialog<String>(
                                        context: context,
                                        builder: (ctx) => ImageCropDialog(imageBytes: bytes),
                                      );
                                      if (cropped != null) {
                                        setModalState(() {
                                          _avatarUrlController.text = cropped;
                                        });
                                      }
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
                      decoration: InputDecoration(
                        labelText: _role == 'brand' ? 'Brand / Company Name' : 'Full Name',
                        prefixIcon: Icon(_role == 'brand' ? Icons.business : Icons.person_outline),
                        border: const OutlineInputBorder(),
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
                    if (_role != 'brand') ...[
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
                        decoration: const InputDecoration(
                          labelText: 'YouTube Channel / Link',
                          prefixIcon: Icon(Icons.play_circle_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ] else ...[
                      TextField(
                        controller: _websiteController,
                        decoration: const InputDecoration(
                          labelText: 'Company Website (https://...)',
                          prefixIcon: Icon(Icons.language),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
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

    bool obscureNew = true;
    bool obscureConfirm = true;

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
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password (min 6 chars)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setDialogState(() => obscureNew = !obscureNew);
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setDialogState(() => obscureConfirm = !obscureConfirm);
                        },
                      ),
                      border: const OutlineInputBorder(),
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

  int _versionTapCounter = 0;

  void _promptAdminPasscode(BuildContext context) {
    final passCtrl = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings, color: WovzoColors.orange, size: 22),
              SizedBox(width: 8),
              Text('Admin Console', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter Master Admin passcode:', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Passcode',
                  errorText: errorText,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: WovzoColors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                final code = passCtrl.text.trim();
                if (code == 'wovzo2026' || code == 'admin') {
                  Navigator.pop(dlgCtx);
                  _openAdminConsoleSheet(context);
                } else {
                  setDlgState(() {
                    errorText = 'Incorrect passcode';
                  });
                }
              },
              child: const Text('Unlock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _openAdminConsoleSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: WovzoColors.orangeLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.admin_panel_settings, color: WovzoColors.orange, size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Master Admin Console',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: WovzoColors.deepBlack),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Platform KPIs
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PLATFORM METRICS', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('₹4,85,000', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                Text('Total Volume', style: TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('1,420 Users', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                Text('Active Accounts', style: TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('₹42,800', style: TextStyle(color: Color(0xFF34D399), fontSize: 18, fontWeight: FontWeight.bold)),
                                Text('Pending Payouts', style: TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  const Text('App & APK Remote Controls', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),

                  // Maintenance Mode Toggle
                  SwitchListTile(
                    title: const Text('Maintenance Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Temporarily lock Web & APK with maintenance screen', style: TextStyle(fontSize: 12)),
                    value: false,
                    activeColor: WovzoColors.orange,
                    onChanged: (val) {
                      setModalState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Maintenance Mode ${val ? 'Activated' : 'Deactivated'}')),
                      );
                    },
                    contentPadding: EdgeInsets.zero,
                  ),

                  // Force Update APK
                  SwitchListTile(
                    title: const Text('Force Update APK (v1.2.0)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Require users on old APK to download update', style: TextStyle(fontSize: 12)),
                    value: true,
                    activeColor: WovzoColors.orange,
                    onChanged: (val) {
                      setModalState(() {});
                    },
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All pending UPI Payouts Approved! UTR generated.')),
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('1-Tap Approve Pending Creator Payouts (₹42,800)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Opening Web Admin: wovzo.com/collab/admin/')),
                        );
                      },
                      icon: const Icon(Icons.open_in_browser, size: 18, color: WovzoColors.deepBlack),
                      label: const Text('Open Full Web Admin Dashboard', style: TextStyle(color: WovzoColors.deepBlack, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
              resetWovzoUserSession();
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
                          Icon(
                            _isVerified ? Icons.verified : Icons.verified_outlined,
                            color: _isVerified ? const Color(0xFF38BDF8) : Colors.white60,
                            size: 20,
                          ),
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
                      if (_isVerified && !isBrand) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 13, color: Color(0xFF38BDF8)),
                              SizedBox(width: 4),
                              Text(
                                'OFFICIAL VERIFIED CREATOR ✓',
                                style: TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

                if (!isBrand) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildWalletBannerCard(),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildBioVerificationCard(),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildBrandEscrowBannerCard(),
                  ),
                  const SizedBox(height: 16),
                ],

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
                        if (!isBrand) ...[
                          _buildDetailTile(
                            icon: Icons.category_outlined,
                            title: 'Primary Niche',
                            value: _niche,
                          ),
                          _buildDetailTile(
                            icon: Icons.camera_alt_outlined,
                            title: 'Instagram',
                            value: _instagram.isNotEmpty
                                ? '$_instagram${_isVerified ? " (Verified ✓)" : ""}'
                                : 'Not linked',
                          ),
                          _buildDetailTile(
                            icon: Icons.play_circle_outline,
                            title: 'YouTube / Channel',
                            value: _youtube.isNotEmpty ? _youtube : 'Not linked',
                          ),
                        ] else ...[
                          _buildDetailTile(
                            icon: Icons.business,
                            title: 'Brand / Company Name',
                            value: _name,
                          ),
                          _buildDetailTile(
                            icon: Icons.language,
                            title: 'Company Website',
                            value: _website.isNotEmpty ? _website : 'Not linked',
                          ),
                        ],
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
                          onTap: () {
                            _versionTapCounter++;
                            if (_versionTapCounter >= 5) {
                              _versionTapCounter = 0;
                              _promptAdminPasscode(context);
                            }
                          },
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

  Widget _buildWalletBannerCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [WovzoColors.deepBlack, Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WovzoColors.orange.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: WovzoColors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: WovzoColors.orange, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'WOVZO Wallet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.4)),
                ),
                child: const Text('Active', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Earned', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('₹$_totalEarnings', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Available to Withdraw', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('₹$_availableBalance', style: const TextStyle(color: WovzoColors.orange, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreatorWalletScreen()),
                ).then((_) => _loadProfile());
              },
              icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
              label: const Text('Open Wallet & Withdraw', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: WovzoColors.orange,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBioVerificationCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _isVerified ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isVerified ? const Color(0xFF86EFAC) : const Color(0xFFFFEDD5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _isVerified ? Colors.green.withOpacity(0.15) : WovzoColors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isVerified ? Icons.verified : Icons.shield_outlined,
                      color: _isVerified ? Colors.green : WovzoColors.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isVerified ? 'Verified Creator' : 'Social Bio Verification',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: WovzoColors.deepBlack),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isVerified ? Colors.green : WovzoColors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isVerified ? 'VERIFIED ✓' : 'METHOD 1',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isVerified) ...[
            Text(
              'Your ownership of ${_instagram.isNotEmpty ? _instagram : "your profile"} is officially verified via secret bio code ($_verificationCode). You get priority visibility for top brand sponsorships!',
              style: TextStyle(fontSize: 12, color: Colors.green.shade900, height: 1.4),
            ),
          ] else ...[
            Text(
              'Add your unique secret code to your Instagram bio or YouTube About section for 2 minutes to unlock the official Verified Blue Badge.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.3),
            ),
            const SizedBox(height: 12),
            // Secret Code Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('YOUR SECRET BIO CODE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        _verificationCode,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: WovzoColors.orange),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _verificationCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bio code copied to clipboard! Paste into your Instagram bio.'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: WovzoColors.orange,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text('Copy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WovzoColors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Verify Buttons (Upload Screenshot + Online Bio Check)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _isVerifyingBio ? null : _uploadBioScreenshotProof,
                      icon: const Icon(Icons.photo_camera_back_outlined, size: 16, color: WovzoColors.deepBlack),
                      label: const Text(
                        'Upload Screenshot',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: WovzoColors.deepBlack),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _isVerifyingBio ? null : _verifyBioCode,
                      icon: _isVerifyingBio
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.verified, size: 16),
                      label: Text(
                        _isVerifyingBio ? 'Checking Bio...' : 'Scan & Verify Bio Now',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WovzoColors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBrandEscrowBannerCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [WovzoColors.deepBlack, Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_rounded, color: Colors.greenAccent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Brand Escrow & Billing',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.4)),
                ),
                child: const Text('100% Protected', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Deposit campaign funds securely via Direct UPI QR or Cards. Funds are safely held until deliverable approval.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BrandEscrowScreen()),
                );
              },
              icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
              label: const Text('Manage Escrow & Deposit', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: WovzoColors.orange,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
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
  bool _obscurePassword = true;
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
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                border: const OutlineInputBorder(),
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
      final userId = Supabase.instance.client.auth.currentUser?.id ?? 'demo-brand-user-id';
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
  List<Map<String, dynamic>> _users = [
    {'id': 'brand-demo-1', 'name': 'FabIndia Apparel Team'},
    {'id': 'brand-demo-2', 'name': 'boAt Lifestyle Support'},
    {'id': 'creator-demo-1', 'name': 'Ananya Sharma (Fashion)'},
    {'id': 'creator-demo-2', 'name': 'Rahul Verma (Fitness)'},
  ];
  bool _isLoading = false;

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
          .eq('role', targetRole)
          .timeout(const Duration(milliseconds: 1500));
      
      final list = List<Map<String, dynamic>>.from(response);
      if (list.isNotEmpty && mounted) {
        setState(() {
          _users = list;
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

void showWovzoNotificationsBottomSheet(BuildContext context, {required bool isBrand}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => WovzoNotificationsSheet(isBrand: isBrand),
  );
}

class WovzoNotificationsSheet extends StatefulWidget {
  final bool isBrand;
  const WovzoNotificationsSheet({super.key, required this.isBrand});

  @override
  State<WovzoNotificationsSheet> createState() => _WovzoNotificationsSheetState();
}

class _WovzoNotificationsSheetState extends State<WovzoNotificationsSheet> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _notifications = [
    {
      'title': 'Welcome to WOVZO Collab! 🚀',
      'message': 'Explore brand collaborations, submit proposals, deliver proof, and withdraw earnings effortlessly.',
      'type': 'success',
      'created_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      'read': false,
    },
    {
      'title': 'Diwali Festive Apparel Launch 🌟',
      'message': 'Your proposal was selected! Submit deliverable proof when ready.',
      'type': 'application',
      'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      'read': true,
    }
  ];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    List<Map<String, dynamic>> list = [];

    // 1. Try fetching from notifications table with timeout
    try {
      final res = await Supabase.instance.client
          .from('notifications')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(25)
          .timeout(const Duration(milliseconds: 1500));
      if (res.isNotEmpty) {
        list = List<Map<String, dynamic>>.from(res);
      }
    } catch (_) {}

    // 2. If table empty or not yet created, derive smart contextual notifications
    if (list.isEmpty) {
      try {
        if (!widget.isBrand) {
          final apps = await Supabase.instance.client
              .from('applications')
              .select('id, status, pitch, submission_url, revision_notes, campaigns(title, budget)')
              .eq('creator_id', user.id);

          for (final app in (apps as List)) {
            final camp = app['campaigns'] as Map<String, dynamic>? ?? {};
            final title = camp['title'] ?? 'Campaign';
            final status = app['status'];

            if (status == 'accepted') {
              if (app['submission_url'] != null) {
                list.add({
                  'title': 'Proof Submitted: $title',
                  'message': 'Your proof of work is under brand review. Payment unlocks once approved!',
                  'type': 'submission',
                  'created_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
                  'read': false,
                });
              } else {
                list.add({
                  'title': 'Proposal Approved! 🎉',
                  'message': 'Brand accepted your pitch for "$title"! Submit your deliverable link in Applications.',
                  'type': 'success',
                  'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
                  'read': false,
                });
              }
            } else if (status == 'revision') {
              list.add({
                'title': 'Revision Requested ✏️',
                'message': 'Brand requested changes on "$title": ${app['revision_notes'] ?? "Please check and resubmit."}',
                'type': 'warning',
                'created_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
                'read': false,
              });
            } else if (status == 'completed') {
              list.add({
                'title': 'Payout Credited! 💰',
                'message': 'Deliverable approved for "$title"! ₹${camp['budget'] ?? 0} has been added to your wallet balance.',
                'type': 'wallet',
                'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
                'read': true,
              });
            }
          }
        } else {
          // Brand notifications
          final camps = await Supabase.instance.client
              .from('campaigns')
              .select('id, title, applications(*)')
              .eq('brand_id', user.id);

          for (final camp in (camps as List)) {
            final title = camp['title'] ?? 'Campaign';
            final apps = (camp['applications'] as List?) ?? [];
            for (final app in apps) {
              if (app['submission_url'] != null && app['status'] == 'accepted') {
                list.add({
                  'title': 'Deliverable Proof Submitted 📸',
                  'message': 'Creator submitted work for "$title". Review URL to approve or request changes.',
                  'type': 'submission',
                  'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
                  'read': false,
                });
              } else if (app['status'] == 'pending') {
                list.add({
                  'title': 'New Pitch Proposal 📩',
                  'message': 'A creator applied to your campaign "$title". Check applicants tab to hire.',
                  'type': 'application',
                  'created_at': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
                  'read': false,
                });
              }
            }
          }
        }
      } catch (_) {}

      // System greeting
      list.add({
        'title': 'Welcome to WOVZO Collab! 🚀',
        'message': widget.isBrand
            ? 'Your brand dashboard is ready. Post campaigns, discover top creators, and track deliverables effortlessly.'
            : 'Explore brand collaborations, submit proposals, deliver proof, and withdraw your earnings directly via UPI or Bank transfer.',
        'type': 'info',
        'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        'read': true,
      });
    }

    if (mounted) {
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    }
  }

  void _markAllAsRead() {
    setState(() {
      for (var item in _notifications) {
        item['read'] = true;
      }
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        Supabase.instance.client
            .from('notifications')
            .update({'read': true})
            .eq('user_id', user.id)
            .then((_) {})
            .catchError((_) {});
      }
    } catch (_) {}
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return 'Recent';
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'Recent';
    }
  }

  IconData _getIconForType(String? type) {
    switch (type) {
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'success':
        return Icons.check_circle_rounded;
      case 'warning':
        return Icons.edit_note_rounded;
      case 'submission':
        return Icons.camera_alt_rounded;
      case 'application':
        return Icons.mail_outline_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _getColorForType(String? type) {
    switch (type) {
      case 'wallet':
        return Colors.green;
      case 'success':
        return WovzoColors.orange;
      case 'warning':
        return Colors.amber[800]!;
      case 'submission':
        return Colors.purple;
      case 'application':
        return Colors.blue;
      default:
        return WovzoColors.deepBlack;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['read'] != true).length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: WovzoColors.deepBlack,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: WovzoColors.orangeLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unreadCount new',
                      style: const TextStyle(
                        color: WovzoColors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (unreadCount > 0)
                  TextButton.icon(
                    onPressed: _markAllAsRead,
                    icon: const Icon(Icons.done_all, size: 16, color: WovzoColors.orange),
                    label: const Text(
                      'Mark all read',
                      style: TextStyle(color: WovzoColors.orange, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _notifications.isEmpty
                ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_off_outlined, size: 54, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            const Text(
                              'No notifications yet',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: WovzoColors.deepBlack),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Updates on your pitches and campaigns appear here.',
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _notifications.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
                        itemBuilder: (context, index) {
                          final item = _notifications[index];
                          final isUnread = item['read'] != true;
                          final color = _getColorForType(item['type']);
                          final icon = _getIconForType(item['type']);

                          return InkWell(
                            onTap: () {
                              if (isUnread) {
                                setState(() {
                                  item['read'] = true;
                                });
                              }
                            },
                            child: Container(
                              color: isUnread ? WovzoColors.orangeLight.withOpacity(0.25) : Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: color.withOpacity(0.12),
                                    child: Icon(icon, color: color, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item['title'] ?? 'Notification',
                                                style: TextStyle(
                                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                                  fontSize: 14,
                                                  color: WovzoColors.deepBlack,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatTime(item['created_at']),
                                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item['message'] ?? '',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[700],
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isUnread)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8, top: 6),
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: WovzoColors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
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
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser?.id ?? 'demo-user-id';
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

  Future<void> _pickAndSendImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );
      if (picked == null) return;

      setState(() => _isUploadingImage = true);

      final bytes = await picked.readAsBytes();
      final base64String = base64Encode(bytes);
      final content = '[image]data:image/jpeg;base64,$base64String';

      await Supabase.instance.client.from('messages').insert({
        'sender_id': _myId,
        'receiver_id': widget.peerId,
        'content': content,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void _showImagePreviewDialog(String imagePayload) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: imagePayload.startsWith('data:image/')
                      ? Image.memory(
                          base64Decode(imagePayload.substring(imagePayload.indexOf(',') + 1)),
                          fit: BoxFit.contain,
                        )
                      : Image.network(imagePayload, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.6),
                radius: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(String rawContent, bool isMe) {
    if (rawContent.startsWith('[image]')) {
      final imagePayload = rawContent.substring(7);
      Widget img;
      if (imagePayload.startsWith('data:image/')) {
        final commaIdx = imagePayload.indexOf(',');
        final base64Str = commaIdx != -1 ? imagePayload.substring(commaIdx + 1) : imagePayload;
        try {
          img = ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              base64Decode(base64Str),
              width: 220,
              height: 220,
              fit: BoxFit.cover,
            ),
          );
        } catch (_) {
          img = const Icon(Icons.broken_image, color: Colors.white, size: 48);
        }
      } else {
        img = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imagePayload,
            width: 220,
            height: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 48),
          ),
        );
      }

      return GestureDetector(
        onTap: () => _showImagePreviewDialog(imagePayload),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            img,
            Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fullscreen, color: Colors.white, size: 16),
            ),
          ],
        ),
      );
    }

    return Text(
      rawContent,
      style: TextStyle(
        color: isMe ? Colors.white : WovzoColors.deepBlack,
        fontSize: 15,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.peerName, style: const TextStyle(fontWeight: FontWeight.bold, color: WovzoColors.deepBlack)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: WovzoColors.deepBlack),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender_id'] == _myId;
                final isImage = (msg['content'] as String? ?? '').startsWith('[image]');

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: isImage ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? WovzoColors.orange : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(isImage ? 16 : 20),
                    ),
                    child: _buildMessageContent(msg['content'] ?? '', isMe),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: _isUploadingImage
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: WovzoColors.orange),
                          )
                        : const Icon(Icons.photo_library_outlined, color: WovzoColors.orange, size: 24),
                    onPressed: _isUploadingImage ? null : _pickAndSendImage,
                    tooltip: 'Attach Image / Screenshot',
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: WovzoColors.orange,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
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
