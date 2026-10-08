with open("lib/main.dart", "r") as f:
    content = f.read()

content = content.replace("if (profile['role'] != _selectedRole) {", "if (profile!['role'] != _selectedRole) {")
content = content.replace("as a ${profile['role']}.';", "as a ${profile!['role']}.';")

with open("lib/main.dart", "w") as f:
    f.write(content)
