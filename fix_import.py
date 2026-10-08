with open("lib/main.dart", "r") as f:
    content = f.read()

content = content.replace("import 'dart:async';\n\nclass _LoginScreenState", "class _LoginScreenState")
content = content.replace("import 'dart:async';\n", "")

content = "import 'dart:async';\n" + content

with open("lib/main.dart", "w") as f:
    f.write(content)
