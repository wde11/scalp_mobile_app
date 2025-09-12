import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search here...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildChatListItem(
                  'John Doe',
                  'Hello, are you interested?',
                  '30 min',
                ),
                _buildChatListItem(
                  'Jane Smith',
                  'Are you ready for today\'s part..',
                  '12 mar',
                ),
                _buildChatListItem(
                  'Peter Jones',
                  'I\'m sending you a parcel rece..',
                  '08 Feb',
                ),
                _buildChatListItem(
                  'Mary Williams',
                  'Hope you\'re doing well today..',
                  '02 Feb',
                ),
                _buildChatListItem(
                  'David Brown',
                  'Let\'s get back to the work, You..',
                  '25 Jan',
                ),
                _buildChatListItem(
                  'Susan Davis',
                  'Listen Troy, i have a problem..',
                  '18 Jan',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatListItem(String name, String message, String time) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundImage: NetworkImage('https://via.placeholder.com/150'),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(message),
      trailing: Text(time, style: const TextStyle(color: Colors.grey)),
      onTap: () {},
    );
  }
}
