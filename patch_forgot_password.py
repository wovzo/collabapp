import re

with open("lib/main.dart", "r") as f:
    content = f.read()

# Add _resetPassword method to _LoginScreenState
reset_logic = """
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
        _errorMessage = 'An unexpected error occurred';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
"""

content = content.replace("  @override\n  void dispose() {", reset_logic + "\n  @override\n  void dispose() {")

# Add "Forgot Password?" button below the Password TextField
button_ui = """                  border: OutlineInputBorder(
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
              
              if (_isLogin) const SizedBox(height: 8),"""

content = re.sub(r"                  border: OutlineInputBorder\(\n                    borderRadius: BorderRadius.circular\(12\),\n                  \),\n                \),\n              \),\n              const SizedBox\(height: 32\),", button_ui + "\n              const SizedBox(height: 16),", content)


with open("lib/main.dart", "w") as f:
    f.write(content)

print("Forgot Password Patched!")
