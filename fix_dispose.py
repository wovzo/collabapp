with open("lib/main.dart", "r") as f:
    content = f.read()

target = """  @override
  void dispose() {
    _emailController.dispose();"""

replacement = """  @override
  void dispose() {
    _authSubscription.cancel();
    _emailController.dispose();"""

content = content.replace(target, replacement)
with open("lib/main.dart", "w") as f:
    f.write(content)
