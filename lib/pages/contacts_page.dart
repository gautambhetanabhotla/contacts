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
                suffixIcon: searchQuery.isNotEmpty ? IconButton(
                  padding: const EdgeInsets.only(right: 10),
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    searchController.clear();
                    setState(() {
                      searchQuery = '';
                    });
                  },
                ) : null,
              ),
              onChanged: (value) {
                // Implement search functionality
                setState(() {
                  searchQuery = value;
                });
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Advanced filters'),
                      content: const Text('Coming soon!'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
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
              final filteredContacts = contactList.where((contact) {
                if (searchQuery.isEmpty) return true;
                final query = searchQuery.toLowerCase();
                if (contact.fullName.toLowerCase().contains(query)) return true;
                final emails = contact["emails"] as List<dynamic>? ?? [];
                if (emails.any((e) => ((e as Map<String, dynamic>)["address"] as String? ?? "").toLowerCase().contains(query))) {
                  return true;
                }
                final phones = contact["phones"] as List<dynamic>? ?? [];
                if (phones.any((p) => ((p as Map<String, dynamic>)["number"] as String? ?? "").contains(query))) {
                  return true;
                }
                return false;
              }).toList();
              
              return ListView.builder(
                itemCount: filteredContacts.length,
                itemBuilder: (context, index) {
                  final contact = filteredContacts[index];
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
