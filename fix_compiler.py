import re

with open("lib/main.dart", "r") as f:
    content = f.read()

# Fix 1: Check where _LoginScreenState is
if "class _LoginScreenState" not in content:
    # Maybe it was deleted? Let's see if the class is completely gone or just malformed.
    print("Warning: _LoginScreenState class completely missing!")
    
# Wait, earlier I did a replace on import dart async:
# content = content.replace("import 'dart:async';\\n\\nclass _LoginScreenState", "class _LoginScreenState")
# Maybe that broke it. Let's just grep for LoginScreenState.

# Fix 2: .eq('brand_id', userId) -> .eq('brand_id', userId ?? '')
content = content.replace(".eq('brand_id', userId)", ".eq('brand_id', userId ?? '')")

with open("lib/main.dart", "w") as f:
    f.write(content)
