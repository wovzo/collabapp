with open("lib/main.dart", "r") as f:
    content = f.read()

content = content.replace("'_errorMessage = 'An unexpected error occurred';", "_errorMessage = 'Error: $e';")
# Wait, single quotes might be tricky, let's just do it cleanly
old_catch = """    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred';
      });
    }"""
new_catch = """    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    }"""

content = content.replace(old_catch, new_catch)

with open("lib/main.dart", "w") as f:
    f.write(content)
