with open("lib/main.dart", "r") as f:
    content = f.read()

content = content.replace("late final StreamSubscription _subscription;", "late final RealtimeChannel _channel;")
content = content.replace("_subscription = Supabase.instance.client", "_channel = Supabase.instance.client")
content = content.replace("_subscription.cancel();", "Supabase.instance.client.removeChannel(_channel);")

with open("lib/main.dart", "w") as f:
    f.write(content)
