import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmailAddress {
  final String email;
  final bool primary;

  EmailAddress({
    required this.email,
    required this.primary,
  });

  factory EmailAddress.fromJson(Map<String, dynamic> json) {
    return EmailAddress(
      email: json['Email address'] as String,
      primary: json['Primary'] as bool,
    );
  }
}

class PhoneNumber {
  final String countryCode;
  final String number;
  final bool primary;

  PhoneNumber({
    required this.countryCode,
    required this.number,
    required this.primary,
  });

  factory PhoneNumber.fromJson(Map<String, dynamic> json) {
    return PhoneNumber(
      countryCode: json['Country code'] as String,
      number: json['Phone number'] as String,
      primary: json['Primary'] as bool,
    );
  }
}

class Contact {
  final String id;
  final String firstName;
  final String lastName;
  final List<PhoneNumber> phoneNumbers;
  final List<EmailAddress> emails;

  Contact({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phoneNumbers,
    required this.emails,
  });
  
  factory Contact.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Contact(
      id: doc.id,
      firstName: data['First name'] ?? '',
      lastName: data['Last name'] ?? '',
      phoneNumbers: List<PhoneNumber>.from(
        (data['Phone numbers'] ?? []).map(
          (item) => PhoneNumber.fromJson(item as Map<String, dynamic>),
        ),
      ),
      emails: List<EmailAddress>.from(
        (data['Email addresses'] ?? []).map(
          (item) => EmailAddress.fromJson(item as Map<String, dynamic>),
        ),
      ),
    );
  }
}

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
        .collection('Contact')
        .where('user', isEqualTo: user.uid)
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
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(contact.firstName.isNotEmpty ?
                          contact.firstName[0] : (contact.lastName.isNotEmpty ?
                          contact.lastName[0] : 'U')),
                      ),
                      title: Text('${contact.firstName} ${contact.lastName}'),
                      subtitle: Text(contact.phoneNumbers.map((e) => e.number).join(', ')),
                      trailing: IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () {
                          _showContactOptions(context, contact);
                        },
                      ),
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
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('${contact.firstName} ${contact.lastName}'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    child: Text(
                      contact.firstName.isNotEmpty ?
                        contact.firstName[0] : (contact.lastName.isNotEmpty ?
                        contact.lastName[0] : 'U'),
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.phone),
                    title: const Text('Phone'),
                    subtitle: Text(contact.phoneNumbers
                      .map((e) => e.number)
                      .join(', '),
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('Email'),
                    subtitle: Text(contact.emails
                      .map((e) => e.email)
                      .join(', '),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContactOptions(BuildContext context, Contact contact) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _showEditContactDialog(context, contact);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteContact(contact);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddContactDialog(BuildContext context) {
    final nameController = TextEditingController();
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
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
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
              if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                _addContact(
                  nameController.text,
                  phoneController.text,
                  emailController.text,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditContactDialog(BuildContext context, Contact contact) {
    final nameController = TextEditingController(text: contact.firstName);
    final phoneController = TextEditingController(text: contact.phoneNumbers.map((e) => e.number).join(', '));
    final emailController = TextEditingController(text: contact.emails.map((e) => e.email).join(', '));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
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
              if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                _updateContact(
                  contact.id,
                  nameController.text,
                  phoneController.text,
                  emailController.text,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addContact(String name, String phoneNumber, String email) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).collection('contacts').add({
        'name': name,
        'phoneNumber': phoneNumber,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void _updateContact(String contactId, String name, String phoneNumber, String email) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .doc(contactId)
          .update({
        'name': name,
        'phoneNumber': phoneNumber,
        'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void _deleteContact(Contact contact) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .doc(contact.id)
          .delete();
    }
  }
}
