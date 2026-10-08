with open("lib/main.dart", "r") as f:
    content = f.read()

content = content.replace("'Creator Profile',", "'My Profile',")

with open("lib/main.dart", "w") as f:
    f.write(content)
