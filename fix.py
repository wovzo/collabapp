import re

with open('lib/main.dart', 'r') as f:
    content = f.read()

# Let's fix CampaignDetailsScreen button
target_str = """                      child: ElevatedButton(
              onPressed: () async {
                if (campaignId == null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CampaignDetailsScreen(),
                    ),
                  );
                  return;
                }
                
                try {
                  final userId = Supabase.instance.client.auth.currentUser?.id;
                  if (userId == null) return;
                  
                  await Supabase.instance.client.from("applications").insert({
                    "campaign_id": campaignId,
                    "influencer_id": userId,
                  });
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Successfully applied to campaign!")),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("You have already applied or an error occurred.")),
                    );
                  }
                }
              },"""

# The second occurrence is inside CampaignDetailsScreen. We'll change it back to just print or something.
occurrences = content.split(target_str)
if len(occurrences) == 3:
    # 0 is before first, 1 is between first and second, 2 is after second
    correct_second_button = """            child: ElevatedButton(
              onPressed: () {},"""
    
    content = occurrences[0] + target_str + occurrences[1] + correct_second_button + occurrences[2]
    
    with open('lib/main.dart', 'w') as f:
        f.write(content)
    print("Fixed!")
else:
    print("Could not find exact occurrences.", len(occurrences))
