with open("lib/main.dart", "r") as f:
    content = f.read()

# Replace the UI part to show the segmented button ALWAYS, not just !_isLogin
ui_old = """              if (_errorMessage != null)
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

              if (!_isLogin) ...[
                SegmentedButton<String>("""

ui_new = """              if (_errorMessage != null)
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

              SegmentedButton<String>("""
content = content.replace(ui_old, ui_new)

# Remove the closing bracket of if (!_isLogin) ...[
close_old = """                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,"""
close_new = """                ),
                const SizedBox(height: 16),
              if (!_isLogin) ...[
                TextField(
                  controller: _nameController,"""
content = content.replace(close_old, close_new)

# Update _submitAuth logic for login to check role
auth_old = """        if (response.user != null) {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('role')
              .eq('id', response.user!.id)
              .single();

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
        }"""
        
auth_new = """        if (response.user != null) {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('role')
              .eq('id', response.user!.id)
              .single();

          if (profile['role'] != _selectedRole) {
            await Supabase.instance.client.auth.signOut();
            setState(() {
              _errorMessage = 'Incorrect role selected. This email is registered as a ${profile['role']}.';
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
        }"""
content = content.replace(auth_old, auth_new)

with open("lib/main.dart", "w") as f:
    f.write(content)

print("Patched UI and Logic!")
