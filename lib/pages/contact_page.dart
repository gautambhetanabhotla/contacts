import 'package:flutter/material.dart';

import '../contacts_controller.dart';
import '../talker.dart';

import 'package:url_launcher/url_launcher.dart';

class ViewContactPage extends StatelessWidget {
  const ViewContactPage({super.key, required this.contact});
  final Contact contact;

  Future<void> _callNumber(String number) async {
    talker.debug("Calling number: $number");
    // Remove all spaces from the number
    final sanitizedNumber = number.replaceAll(RegExp(r'\s+'), '');
    final Uri url = Uri(scheme: 'tel', path: sanitizedNumber);
    // final Uri url = Uri.parse('https://google.com');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      talker.error("Could not launch $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? firstPhone = (contact["phones"] != null && contact["phones"].isNotEmpty)
        ? contact["phones"][0]["number"]
        : null;

    return Scaffold(
      appBar: AppBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context,
            MaterialPageRoute(
              builder: (context) => EditContactPage(contactData: contact.data),
            ),
          );
        },
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
                  contact.leadingCharacter ?? '',
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                contact.fullName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Phone'),
                subtitle: Text(contact["phones"] != null
                    ? contact["phones"].map((e) => e["number"]).join(', ')
                    : 'No Phone'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Email'),
                subtitle: Text(contact["emails"] != null
                    ? contact["emails"].map((e) => e["address"]).join(', ')
                    : 'No Email'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddContactPage extends StatefulWidget {
  const AddContactPage({super.key, this.contactData});

  final String title = "New contact";
  final Map<String, dynamic>? contactData;

  void _onSave(BuildContext context) {
    // Logic to save the edited contact
    Navigator.pop(context);
    talker.debug("ADDING CONTACT");
  }

  @override
  State<AddContactPage> createState() => _AddContactPageState();
}

class _AddContactPageState extends State<AddContactPage> {

  late bool _isNamePrefixVisible;
  late bool _isMiddleNameVisible;
  late bool _isNameSuffixVisible;
  late bool _isNicknameVisible;

  late final TextEditingController namePrefixController;
  late final TextEditingController firstNameController;
  late final TextEditingController middleNameController;
  late final TextEditingController lastNameController;
  late final TextEditingController nameSuffixController;
  late final TextEditingController nicknameController;
  late final List<Map<String, TextEditingController>> phoneControllers;
  late final List<Map<String, TextEditingController>> emailControllers;

  @override
  void initState() {
    super.initState();

    _isNamePrefixVisible = widget.contactData?['name']['prefix'] != null && widget.contactData?['name']['prefix'].isNotEmpty;
    _isMiddleNameVisible = widget.contactData?['name']['middle'] != null && widget.contactData?['name']['middle'].isNotEmpty;
    _isNameSuffixVisible = widget.contactData?['name']['suffix'] != null && widget.contactData?['name']['suffix'].isNotEmpty;
    _isNicknameVisible = widget.contactData?['nickname'] != null && widget.contactData?['nickname'].isNotEmpty;

    namePrefixController = TextEditingController(text: widget.contactData?['name']['prefix'] ?? '');
    firstNameController = TextEditingController(text: widget.contactData?['name']['first'] ?? '');
    middleNameController = TextEditingController(text: widget.contactData?['name']['middle'] ?? '');
    lastNameController = TextEditingController(text: widget.contactData?['name']['last'] ?? '');
    nameSuffixController = TextEditingController(text: widget.contactData?['name']['suffix'] ?? '');
    nicknameController = TextEditingController(text: widget.contactData?['nickname'] ?? '');
    phoneControllers = (widget.contactData?['phones'] as List<dynamic>?)?.map((phone) {
      return {
        'number': TextEditingController(text: phone['number'] ?? ''),
        'label': TextEditingController(text: phone['label'] ?? ''),
      };
    }).toList() ?? [];
    emailControllers = (widget.contactData?['emails'] as List<dynamic>?)?.map((email) {
      return {
        'address': TextEditingController(text: email['address'] ?? ''),
        'label': TextEditingController(text: email['label'] ?? ''),
      };
    }).toList() ?? [];
  }

  final inputControllerDecoration = const InputDecoration(
    contentPadding: EdgeInsets.all(16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8.0)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(50),
          child: Column(
            spacing: 10,
            children: [
              // const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 100,
                      child: const Icon(Icons.person_outline, size: 140),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Change Photo'),
                      onPressed: () {
                        // Logic to change photo
                        talker.debug('Change Photo Pressed');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Wrap(
                spacing: 6, // space between chips horizontally
                runSpacing: -2, // space between lines
                children: [
                  !_isNamePrefixVisible ? Chip(
                    label: Text("Name Prefix"),
                    deleteIcon: const Icon(Icons.add),
                    onDeleted: () {
                      setState(() {
                        _isNamePrefixVisible = true;
                      });
                    },
                  ) : const SizedBox.shrink(),
                  !_isMiddleNameVisible ? Chip(
                    label: Text("Middle Name"),
                    deleteIcon: const Icon(Icons.add),
                    onDeleted: () {
                      setState(() {
                        _isMiddleNameVisible = true;
                      });
                    },
                  ) : const SizedBox.shrink(),
                  !_isNameSuffixVisible ? Chip(
                    label: Text("Name Suffix"),
                    deleteIcon: const Icon(Icons.add),
                    onDeleted: () {
                      setState(() {
                        _isNameSuffixVisible = true;
                      });
                    },
                  ) : const SizedBox.shrink(),
                  !_isNicknameVisible ? Chip(
                    label: Text("Nickname"),
                    deleteIcon: const Icon(Icons.add),
                    onDeleted: () {
                      setState(() {
                        _isNicknameVisible = true;
                      });
                    },
                  ) : const SizedBox.shrink(),
                ],
              ),
              _isNamePrefixVisible ? TextField(
                controller: namePrefixController,
                decoration: inputControllerDecoration.copyWith(
                  labelText: 'Name Prefix',
                ),
              ) : const SizedBox.shrink(),
              TextField(
                controller: firstNameController,
                decoration: inputControllerDecoration.copyWith(
                  labelText: 'First Name',
                ),
              ),
              _isMiddleNameVisible ? TextField(
                controller: middleNameController,
                decoration: inputControllerDecoration.copyWith(
                  labelText: 'Middle Name',
                ),
              ) : const SizedBox.shrink(),
              TextField(
                controller: lastNameController,
                decoration: inputControllerDecoration.copyWith(
                  labelText: 'Last Name',
                ),
              ),
              _isNameSuffixVisible ? TextField(
                controller: nameSuffixController,
                decoration: inputControllerDecoration.copyWith(
                  labelText: 'Name Suffix',
                ),
              ) : const SizedBox.shrink(),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...phoneControllers.map((controller) => TextField(
                    controller: controller['number'],
                    decoration: inputControllerDecoration.copyWith(
                      labelText: 'Phone Number',
                    ),
                  )),
                  TextButton.icon(
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add Phone Number'),
                    onPressed: () {
                      setState(() {
                        phoneControllers.add({
                          'number': TextEditingController(),
                          'label': TextEditingController(),
                        });
                      });
                    },
                  )
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => widget._onSave(context),
        tooltip: 'Save',
        child: const Icon(Icons.check),
      ),
    );
  }
}

class EditContactPage extends AddContactPage {
  const EditContactPage({super.key, required super.contactData});
  // final Map<String, dynamic> contactData;

  @override
  String get title => "Edit contact";

  @override
  void _onSave(BuildContext context) {
    // Logic to edit an existing contact
    Navigator.pop(context);
    talker.debug('EDITING CONTACT');
  }
}
