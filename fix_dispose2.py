import re

with open("lib/main.dart", "r") as f:
    content = f.read()

pattern = r"class _LoginScreenState extends State<LoginScreen> \{.*?Future<void> _submitAuth\(\) async \{"
replacement = """class _LoginScreenState extends State<LoginScreen> {
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

  @override
  void dispose() {
    _authSubscription.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitAuth() async {"""

content = re.sub(pattern, replacement, content, flags=re.DOTALL)

# And remove the old dispose at the bottom of the class just in case!
content = re.sub(r"  @override\n  void dispose\(\) \{\n    _authSubscription.cancel\(\);\n    _emailController.dispose\(\);\n    _passwordController.dispose\(\);\n    _nameController.dispose\(\);\n    super.dispose\(\);\n  \}", "", content)
# Wait, I just injected the correct dispose at the top, I should remove the one at the bottom, which looks like:
#  @override
#  void dispose() {
#    _authSubscription.cancel();
#    _emailController.dispose();

with open("lib/main.dart", "w") as f:
    f.write(content)
