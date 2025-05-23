import 'package:flutter/material.dart';

import 'contacts_controller.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key, required this.contact, this.isEditMode = false});
  final Contact contact;
  final bool isEditMode;

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.contact["First name"]} ${widget.contact["Last name"]}'),
      ),
      floatingActionButton: FloatingActionButton(onPressed: () {}),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                child: Text(
                  widget.contact.getLeadingCharacter(),
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Phone'),
                subtitle: Text(widget.contact["Phone numbers"]
                  .map((e) => e["Phone number"])
                  .join(', '),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Email'),
                subtitle: Text(widget.contact["Email addresses"]
                  .map((e) => e["Email address"])
                  .join(', '),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}