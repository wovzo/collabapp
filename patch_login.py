import re

with open("lib/main.dart", "r") as f:
    content = f.read()

old_login = """        if (response.user != null) {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('role')
              .eq('id', response.user!.id)
              .single();

          if (profile['role'] != _selectedRole) {"""

new_login = """        if (response.user != null) {
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
               'role': _selectedRole,
               'email': response.user!.email
             });
             profile = {'role': _selectedRole};
          }

          if (profile['role'] != _selectedRole) {"""

content = content.replace(old_login, new_login)

with open("lib/main.dart", "w") as f:
    f.write(content)
