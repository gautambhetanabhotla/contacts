import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    return Scaffold(
      appBar: AppBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context,
            MaterialPageRoute(
              builder: (context) => EditContactPage(initialContactData: contact.data),
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
            const SizedBox(height: 20),
            Center(
              child: CircleAvatar(
                radius: 100,
                child: Text(
                  contact.leadingCharacter ?? '',
                  style: const TextStyle(fontSize: 100),
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
            const SizedBox(height: 40),
            Card(
              color: Theme.of(context).colorScheme.onSecondary,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 24.0, 8.0, 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const SizedBox(width: 16.0), // Match ListTile's leading space
                        Text("Phone", style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    for (var phone in contact["phones"] ?? [])
                      ListTile(
                        subtitle: Text(phone["label"] ?? 'No Label'),
                        title: Text(phone["number"] ?? 'No Number'),
                        trailing: IconButton(icon: const Icon(Icons.call),
                          onPressed: () => _callNumber(phone["number"] ?? ''),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (contact["emails"]?.isNotEmpty ?? false) Card(
              color: Theme.of(context).colorScheme.onSecondary,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 24.0, 8.0, 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        const SizedBox(width: 16.0), // Match ListTile's leading space
                        Text("Email", style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                    for (var email in contact["emails"] ?? [])
                      ListTile(
                        subtitle: Text(email["label"] ?? 'No Label'),
                        title: Text(email["address"] ?? 'No Address'),
                        trailing: IconButton(
                          icon: const Icon(Icons.email_outlined),
                          onPressed: () {
                            final Uri emailUri = Uri(
                              scheme: 'mailto',
                              path: email["address"],
                            );
                            launchUrl(emailUri);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddContactPage extends StatefulWidget {
  const AddContactPage({super.key, this.initialContactData});

  final String title = "New contact";
  final Map<String, dynamic>? initialContactData;

  // Widget method that can be overridden
  Future<void> onSave(BuildContext context, Map<String, dynamic> contactData, Function(bool) setLoadingState) async {
    setLoadingState(true);
    
    try {
      final controller = context.read<ContactsController?>();
      
      if (controller == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contacts controller not available')),
          );
        }
        return;
      }

      await controller.addContact(contactData);
      
      if (context.mounted) {
        Navigator.pop(context);
      }
      
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving contact: $e')),
        );
      }
    } finally {
      setLoadingState(false);
    }
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

    _isNamePrefixVisible = widget.initialContactData?['name']['prefix'] != null && widget.initialContactData?['name']['prefix'].isNotEmpty;
    _isMiddleNameVisible = widget.initialContactData?['name']['middle'] != null && widget.initialContactData?['name']['middle'].isNotEmpty;
    _isNameSuffixVisible = widget.initialContactData?['name']['suffix'] != null && widget.initialContactData?['name']['suffix'].isNotEmpty;
    _isNicknameVisible = widget.initialContactData?['nickname'] != null && widget.initialContactData?['nickname'].isNotEmpty;

    namePrefixController = TextEditingController(text: widget.initialContactData?['name']['prefix'] ?? '');
    firstNameController = TextEditingController(text: widget.initialContactData?['name']['first'] ?? '');
    middleNameController = TextEditingController(text: widget.initialContactData?['name']['middle'] ?? '');
    lastNameController = TextEditingController(text: widget.initialContactData?['name']['last'] ?? '');
    nameSuffixController = TextEditingController(text: widget.initialContactData?['name']['suffix'] ?? '');
    nicknameController = TextEditingController(text: widget.initialContactData?['nickname'] ?? '');
    phoneControllers = (widget.initialContactData?['phones'] as List<dynamic>?)?.map((phone) {
      return {
        'number': TextEditingController(text: phone['number'] ?? ''),
        'label': TextEditingController(text: phone['label'] ?? ''),
      };
    }).toList() ?? [{
      'number': TextEditingController(),
      'label': TextEditingController(),
    }];
    emailControllers = (widget.initialContactData?['emails'] as List<dynamic>?)?.map((email) {
      return {
        'address': TextEditingController(text: email['address'] ?? ''),
        'label': TextEditingController(text: email['label'] ?? ''),
      };
    }).toList() ?? [{
      'address': TextEditingController(),
      'label': TextEditingController(),
    }];
  }

  final inputControllerDecoration = const InputDecoration(
    contentPadding: EdgeInsets.all(16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8.0)),
    ),
  );

  bool _isLoading = false;
  void _setLoadingState(bool loading) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
      });
    }
  }

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
                  if (!_isNamePrefixVisible) Chip(
                    label: Text("Name Prefix"),
                    deleteIcon: const Icon(Icons.add),
                    onDeleted: () {
                      setState(() {
                        _isNamePrefixVisible = true;
                      });
                    },
                  ),
                  if (!_isMiddleNameVisible) Chip(
                    label: Text("Middle Name"),
                    deleteIcon: const Icon(Icons.add),
                    onDeleted: () {
                      setState(() {
                        _isMiddleNameVisible = true;
                      });
                    },
                  ),
                  if (!_isNameSuffixVisible) Chip(
                    label: Text("Name Suffix"),
                    deleteIcon: const Icon(Icons.add),
                    onDeleted: () {
                      setState(() {
                        _isNameSuffixVisible = true;
                      });
                    },
                  ),
                  if (!_isNicknameVisible) Chip(
                    label: Text("Nickname"),
                    deleteIcon: const Icon(Icons.add),
                    onDeleted: () {
                      setState(() {
                        _isNicknameVisible = true;
                      });
                    },
                  ),
                ],
              ),
              if (_isNamePrefixVisible) TextField(
                controller: namePrefixController,
                decoration: inputControllerDecoration.copyWith(
                  labelText: 'Name Prefix',
                ),
              ),
              TextField(
                controller: firstNameController,
                decoration: inputControllerDecoration.copyWith(
                  labelText: 'First Name',
                ),
              ),
              if (_isMiddleNameVisible) TextField(
                controller: middleNameController,
                decoration: inputControllerDecoration.copyWith(
                  labelText: 'Middle Name',
                ),
              ),
              TextField(
                controller: lastNameController,
                decoration: inputControllerDecoration.copyWith(
                  labelText: 'Last Name',
                ),
              ),
              if (_isNameSuffixVisible) TextField(
                controller: nameSuffixController,
                decoration: inputControllerDecoration.copyWith(
                  labelText: 'Name Suffix',
                ),
              ),
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
        onPressed: () => widget.onSave(context, {
          'name': {
            'prefix': namePrefixController.text,
            'first': firstNameController.text,
            'middle': middleNameController.text,
            'last': lastNameController.text,
            'suffix': nameSuffixController.text,
          },
          'nickname': nicknameController.text,
          'phones': phoneControllers.where(
            (element) => element['number']?.text.isNotEmpty == true)
            .map((controller) {
              return {
                'number': controller['number']?.text ?? '',
                'label': controller['label']?.text ?? '',
              };
          }).toList(),
          'emails': emailControllers.where(
            (element) => element['address']?.text.isNotEmpty == true)
            .map((controller) {
              return {
                'address': controller['address']?.text ?? '',
                'label': controller['label']?.text ?? '',
              };
          }).toList(),
          'lastModified': DateTime.now().millisecondsSinceEpoch,
        }, _setLoadingState),
        tooltip: 'Save',
        child: _isLoading ? const CircularProgressIndicator() : const Icon(Icons.check),
      ),
    );
  }
}

class EditContactPage extends AddContactPage {
  const EditContactPage({super.key, required super.initialContactData});
  // final Map<String, dynamic> contactData;

  @override
  String get title => "Edit contact";

  @override
  Future<void> onSave(BuildContext context, Map<String, dynamic> contactData, Function(bool) setLoadingState) async {
    // Save the new contact data
    Navigator.pop(context);
    talker.debug('EDITING CONTACT');
  }
}
