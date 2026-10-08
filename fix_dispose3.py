import re

with open("lib/main.dart", "r") as f:
    content = f.read()

# Let's remove the second dispose method which might look like:
#  @override
#  void dispose() {
#    _authSubscription.cancel();
#    _emailController.dispose();
#    _passwordController.dispose();
#    _nameController.dispose();
#    super.dispose();
#  }
# Wait, I don't know exactly what it looks like. Let's just find the second one and remove it.
matches = [m.start() for m in re.finditer(r"  @override\n  void dispose\(\) \{", content)]
if len(matches) > 1:
    # There is more than one! The second one must be the old one.
    old_dispose_idx = matches[1]
    # Find the closing brace for this method.
    closing_idx = content.find("  }", old_dispose_idx) + 3
    content = content[:old_dispose_idx] + content[closing_idx:]
    with open("lib/main.dart", "w") as f:
        f.write(content)
        print("Removed duplicate dispose.")
else:
    print("Only one dispose found.")
