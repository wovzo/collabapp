with open("lib/main.dart", "r") as f:
    content = f.read()

target = """              TextField(
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
              const SizedBox(height: 24),
              ElevatedButton("""

replacement = """              TextField(
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
                    child: const Text('Forgot Password?'),
                  ),
                )
              else
                const SizedBox(height: 16),
              if (_isLogin) const SizedBox(height: 8),
              ElevatedButton("""

content = content.replace(target, replacement)

with open("lib/main.dart", "w") as f:
    f.write(content)

print("Forgot Password UI Patched!")
