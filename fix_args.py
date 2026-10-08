with open("lib/main.dart", "r") as f:
    content = f.read()

bad_str = "builder: (context) => const CampaignDetailsScreen(),"
good_str = """builder: (context) => CampaignDetailsScreen(
                        brandName: brandName,
                        campaignTitle: campaignTitle,
                        budget: budget,
                        requirements: requirements,
                        color: color,
                      ),"""

content = content.replace(bad_str, good_str)

with open("lib/main.dart", "w") as f:
    f.write(content)
print("Fixed args!")
