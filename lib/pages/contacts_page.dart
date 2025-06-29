import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../contacts_controller.dart';
import 'contact_page.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  String searchQuery = '';
  late TextEditingController searchController;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController(text: searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ContactsController?>(
      builder: (context, contactsController, child) {
        // Handle the case where controller is still loading
        if (contactsController == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts',
                border: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(100.0)),
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: const Icon(Icons.search),
                ),
                suffixIcon: IconButton(
                  padding: const EdgeInsets.only(right: 10),
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    searchController.clear();
                    setState(() {
                      searchQuery = '';
                    });
                  },
                ),
              ),
              onChanged: (value) {
                // Implement search functionality
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () {
                  // Filter functionality
                },
              ),
            ],
          ),
          body: StreamBuilder<List<Contact>>(
            stream: contactsController.contactsStream,
            builder: (context, snapshot) {
              final contactList = snapshot.data ?? [];
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView.builder(
                itemCount: contactList.length,
                itemBuilder: (context, index) {
                  final contact = contactList[index];
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      child: Text(contact.leadingCharacter ?? '?'),
                    ),
                    title: Text(contact.fullName),
                    onTap: () {
                      _viewContactDetails(context, contact);
                    },
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            child: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(context,
                MaterialPageRoute(
                  builder: (context) => const AddContactPage(),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _viewContactDetails(BuildContext context, Contact contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewContactPage(contact: contact)
      ),
    );
  }
}
