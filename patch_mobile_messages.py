import re

with open("lib/main.dart", "r") as f:
    content = f.read()

# 1. Add MessagesScreen and ChatScreen at the bottom
messages_code = """
class MessagesScreen extends StatefulWidget {
  final bool isBrand;
  const MessagesScreen({super.key, required this.isBrand});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final targetRole = widget.isBrand ? 'influencer' : 'brand';
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, name')
          .eq('role', targetRole);
      
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Messages', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? const Center(child: Text('No users found to chat.'))
                    : ListView.builder(
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final u = _users[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue[100],
                              child: Text(u['name']?[0]?.toUpperCase() ?? 'U', style: const TextStyle(color: Colors.blue)),
                            ),
                            title: Text(u['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(peerId: u['id'], peerName: u['name'] ?? 'Unknown')));
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  const ChatScreen({super.key, required this.peerId, required this.peerName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  late final StreamSubscription _subscription;
  String _myId = '';

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser!.id;
    _fetchMessages();
    _setupSubscription();
  }

  Future<void> _fetchMessages() async {
    final response = await Supabase.instance.client
        .from('messages')
        .select('*')
        .or('and(sender_id.eq.$_myId,receiver_id.eq.${widget.peerId}),and(sender_id.eq.${widget.peerId},receiver_id.eq.$_myId)')
        .order('created_at', ascending: true);
    
    if (mounted) {
      setState(() {
        _messages = List<Map<String, dynamic>>.from(response);
      });
    }
  }

  void _setupSubscription() {
    _subscription = Supabase.instance.client
        .channel('public:messages')
        .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              final msg = payload.newRecord;
              if ((msg['sender_id'] == _myId && msg['receiver_id'] == widget.peerId) ||
                  (msg['sender_id'] == widget.peerId && msg['receiver_id'] == _myId)) {
                if (mounted) {
                  setState(() {
                    _messages.add(msg);
                  });
                }
              }
            })
        .subscribe();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _msgController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_msgController.text.trim().isEmpty) return;
    final text = _msgController.text.trim();
    _msgController.clear();
    
    await Supabase.instance.client.from('messages').insert({
      'sender_id': _myId,
      'receiver_id': widget.peerId,
      'content': text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.peerName)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender_id'] == _myId;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      msg['content'],
                      style: TextStyle(color: isMe ? Colors.white : Colors.black),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
"""

content = content + messages_code

# 2. Add to BrandMainScreen
brand_nav_regex = r"class _BrandMainScreenState extends State<BrandMainScreen> \{.*?static const List<Widget> _widgetOptions = <Widget>\[.*?BrandCampaignsScreen\(\),.*?BrandApplicantsScreen\(\),.*?ProfileScreen\(\),.*?\];.*?void _onItemTapped.*?NavigationBar\(.*?destinations: const <NavigationDestination>\[.*?NavigationDestination\(.*?label: 'Profile',.*?\),.*?\]"
match = re.search(brand_nav_regex, content, re.DOTALL)
if match:
    old_brand = match.group(0)
    new_brand = old_brand.replace(
        "ProfileScreen(),", 
        "MessagesScreen(isBrand: true),\n    ProfileScreen(),"
    ).replace(
        "NavigationDestination(\n            icon: Icon(Icons.person_outline),\n            selectedIcon: Icon(Icons.person),\n            label: 'Profile',\n          ),",
        "NavigationDestination(\n            icon: Icon(Icons.chat_bubble_outline),\n            selectedIcon: Icon(Icons.chat_bubble),\n            label: 'Messages',\n          ),\n          NavigationDestination(\n            icon: Icon(Icons.person_outline),\n            selectedIcon: Icon(Icons.person),\n            label: 'Profile',\n          ),"
    )
    content = content.replace(old_brand, new_brand)

# 3. Add to InfluencerMainScreen
inf_nav_regex = r"class _InfluencerMainScreenState extends State<InfluencerMainScreen> \{.*?static const List<Widget> _widgetOptions = <Widget>\[.*?ExploreScreen\(\),.*?ApplicationsScreen\(\),.*?ProfileScreen\(\),.*?\];.*?void _onItemTapped.*?NavigationBar\(.*?destinations: const <NavigationDestination>\[.*?NavigationDestination\(.*?label: 'Profile',.*?\),.*?\]"
match2 = re.search(inf_nav_regex, content, re.DOTALL)
if match2:
    old_inf = match2.group(0)
    new_inf = old_inf.replace(
        "ProfileScreen(),", 
        "MessagesScreen(isBrand: false),\n    ProfileScreen(),"
    ).replace(
        "NavigationDestination(\n            icon: Icon(Icons.person_outline),\n            selectedIcon: Icon(Icons.person),\n            label: 'Profile',\n          ),",
        "NavigationDestination(\n            icon: Icon(Icons.chat_bubble_outline),\n            selectedIcon: Icon(Icons.chat_bubble),\n            label: 'Messages',\n          ),\n          NavigationDestination(\n            icon: Icon(Icons.person_outline),\n            selectedIcon: Icon(Icons.person),\n            label: 'Profile',\n          ),"
    )
    content = content.replace(old_inf, new_inf)

with open("lib/main.dart", "w") as f:
    f.write(content)
print("Mobile Messages Patched")
