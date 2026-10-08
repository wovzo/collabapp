with open("lib/main.dart", "r") as f:
    content = f.read()

# Add UpdatePasswordScreen at the end
update_pwd_screen = """
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
"""
content = content + update_pwd_screen

# Add auth state listener to LoginScreen
login_state = """class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();"""

login_state_with_listener = """import 'dart:async';\n\nclass _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  late final StreamSubscription<AuthState> _authSubscription;

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

  @override
  void dispose() {
    _authSubscription.cancel();
"""

content = content.replace(login_state, login_state_with_listener.replace("\n  @override\n  void dispose() {", ""))

with open("lib/main.dart", "w") as f:
    f.write(content)

print("Recovery patched")
