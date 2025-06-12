import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../talker.dart';
import '../contacts_controller.dart';
import 'contact_page.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String searchQuery = '';
  late TextEditingController searchController;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController(text: searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    final contactsController = context.read<ContactsController>();
    return Scaffold(
      appBar: AppBar(
      // Replace the standard AppBar with a search bar
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
                // Clear the search field
                searchController.clear();
                setState(() {
                  searchQuery = '';
                });
              },
            ),
          ),
          onChanged: (value) {
            // Implement search functionality
            // Filter contacts based on search query
          },
        ),
        actions: [
          // Optional: Add a clear button or other actions
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // Clear the search field
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Contact>>(
        stream: contactsController.contactsStream,
        builder: (context, snapshot) {
          final contactList = snapshot.data ?? [];
          talker.debug(contactList);
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: contactList.length,
            itemBuilder: (context, index) {
              final contact = contactList[index];
              talker.debug(contact);
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
          _showAddContactDialog(context);
        },
      ),
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

  void _showAddContactDialog(BuildContext context) {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                decoration: InputDecoration(labelText: 'First name')
              ),
              TextField(
                controller: lastNameController,
                decoration: InputDecoration(labelText: 'Last name'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (firstNameController.text.isNotEmpty) {
                _addContact({
                  "First name": firstNameController.text,
                  "Last name": lastNameController.text,
                  "Phone numbers": [
                    {
                      "Country code": "+91",
                      "Phone number": phoneController.text,
                      "primary": true,
                    }
                  ],
                  "Email addresses": [
                    {
                      "Email address": emailController.text,
                      "primary": true,
                    }
                  ],
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addContact(Map<String, dynamic> contactData) async {
    final user = _auth.currentUser;
    Map<String, dynamic> newData = contactData;
    newData["Created at"] = FieldValue.serverTimestamp();
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).collection('contacts').add(newData);
    }
  }
}
