with open("lib/main.dart", "r") as f:
    content = f.read()

bad_closing = """              ),
            ],
          ),
        ),
      ),
    );
  }
}"""

good_closing = """              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}"""

content = content.replace(bad_closing, good_closing)

with open("lib/main.dart", "w") as f:
    f.write(content)
