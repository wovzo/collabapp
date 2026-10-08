with open("lib/main.dart", "r") as f:
    content = f.read()

content = content.replace(",\n               'email': response.user!.email", "")

with open("lib/main.dart", "w") as f:
    f.write(content)
