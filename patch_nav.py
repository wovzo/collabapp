with open("lib/main.dart", "r") as f:
    content = f.read()

content = content.replace("    Center(child: Text('Messages - Coming Soon')),\n", "")
content = content.replace("""          NavigationDestination(
            icon: Icon(Icons.message_outlined),
            selectedIcon: Icon(Icons.message),
            label: 'Messages',
          ),\n""", "")

with open("lib/main.dart", "w") as f:
    f.write(content)
