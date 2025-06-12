import 'package:flutter/material.dart';

import '../contacts_controller.dart';

class ViewContactPage extends StatefulWidget {
  const ViewContactPage({super.key, required this.contact});
  final Contact contact;

  @override
  State<ViewContactPage> createState() => _ViewContactPageState();
}

class _ViewContactPageState extends State<ViewContactPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(

      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {

        },
        tooltip: 'Edit Contact',
        child: const Icon(Icons.edit),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            Center(
              child: CircleAvatar(
                radius: 50,
                child: Text(
                  widget.contact.leadingCharacter ?? '',
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(widget.contact.fullName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Phone'),
                subtitle: Text(widget.contact["phones"]
                  .map((e) => e["number"])
                  .join(', '),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Email'),
                subtitle: Text(widget.contact["emails"]
                  .map((e) => e["address"])
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