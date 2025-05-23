import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import './talker.dart';
import './contacts_controller.dart';
import './contact_page.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  late Stream<QuerySnapshot> _contactsStream;
  
  @override
  void initState() {
    super.initState();
    _setupContactsStream();
  }
  
  void _setupContactsStream() {
    final user = _auth.currentUser;
    // print(user?.uid);
    if (user != null) {
      _contactsStream = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('contacts')
        .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Implement search functionality
            },
          ),
        ],
      ),
      body: _auth.currentUser == null
          ? const Center(child: Text('You need to be logged in to view contacts'))
          : StreamBuilder<QuerySnapshot>(
              stream: _contactsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: SelectableText('Error: ${snapshot.error}'));
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No contacts found'));
                }
                
                final contacts = snapshot.data!.docs
                    .map((doc) => Contact.fromFirestore(doc))
                    .toList();
                
                return ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    talker.debug(contact);
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        child: Text(contact.getLeadingCharacter()),
                      ),
                      title: Text('${contact["First name"]} ${contact["Last name"] ?? ''}'),
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
        builder: (context) => ContactPage(contact: contact)
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
