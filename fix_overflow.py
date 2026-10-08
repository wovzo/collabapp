with open("lib/main.dart", "r") as f:
    content = f.read()

old_scroll = """      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,"""

new_scroll = """      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,"""

content = content.replace(old_scroll, new_scroll)

with open("lib/main.dart", "w") as f:
    f.write(content)

print("Overflow fixed!")
