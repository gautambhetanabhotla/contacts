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
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      talker.error("Could not launch $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ContactsController?>(
      builder: (context, controller, child) {
        if (controller == null) {
          talker.warning("Null controller");
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return StreamBuilder<List<Contact>>(
          stream: controller.contactsStream,
          initialData: controller.mergedContacts.values.toList(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              talker.warning("No data");
              return Scaffold(
                appBar: AppBar(),
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Find the updated contact from the stream
            Contact? updatedContact;
            try {
              updatedContact = snapshot.data!.firstWhere((c) => c == contact);
            } catch (e) {
              // Contact not found, might have been deleted
              updatedContact = contact; // Fallback to original
            }

            return Scaffold(
              appBar: AppBar(),
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  Navigator.push(context,
                    MaterialPageRoute(
                      builder: (context) => EditContactPage(initialContactData: updatedContact!.data),
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
                          updatedContact.leadingCharacter ?? '',
                          style: const TextStyle(fontSize: 100),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        updatedContact.fullName,
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
                                const SizedBox(width: 16.0),
                                Text("Phone", style: Theme.of(context).textTheme.titleLarge),
                              ],
                            ),
                            for (var phone in updatedContact["phones"] ?? [])
                              ListTile(
                                subtitle: Text(phone["label"] ?? 'No Label'),
                                title: Text(phone["number"] ?? 'No Number'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.call),
                                  onPressed: () => _callNumber(phone["number"] ?? ''),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (updatedContact["emails"]?.isNotEmpty ?? false) Card(
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
                                const SizedBox(width: 16.0),
                                Text("Email", style: Theme.of(context).textTheme.titleLarge),
                              ],
                            ),
                            for (var email in updatedContact["emails"] ?? [])
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
          },
        );
      },
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
    // talker.debug(widget.initialContactData?['emails']);
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
              // const SizedBox(height: 30),
              Wrap(
                spacing: 6, // space between chips horizontally
                runSpacing: -4, // space between lines
                children: [
                  if (!_isNamePrefixVisible) Chip(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    padding: const EdgeInsets.all(4.0),
                    label: Text("Name prefix"),
                    deleteIcon: const Icon(Icons.add),
                    onDeleted: () {
                      setState(() {
                        _isNamePrefixVisible = true;
                      });
                    },
                  ),
                  if (!_isMiddleNameVisible) Chip(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    padding: const EdgeInsets.all(4.0),
                    label: Text("Middle name"),
                    deleteIcon: const Icon(Icons.add),
                    onDeleted: () {
                      setState(() {
                        _isMiddleNameVisible = true;
                      });
                    },
                  ),
                  if (!_isNameSuffixVisible) Chip(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    padding: const EdgeInsets.all(4.0),
                    label: Text("Name suffix"),
                    deleteIcon: const Icon(Icons.add),
                    onDeleted: () {
                      setState(() {
                        _isNameSuffixVisible = true;
                      });
                    },
                  ),
                  if (!_isNicknameVisible) Chip(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    padding: const EdgeInsets.all(4.0),
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
                spacing: 10,
                children: [
                  for (var controller in phoneControllers)
                    TextField(
                      controller: controller['number'],
                      decoration: inputControllerDecoration.copyWith(
                        labelText: 'Phone Number',
                      ),
                    ),
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
                  ),
                ],
              ),
              
              // const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  for (var controller in emailControllers)
                    TextField(
                      controller: controller['address'],
                      decoration: inputControllerDecoration.copyWith(
                        labelText: 'Email Address',
                      ),
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add email'),
                    onPressed: () {
                      setState(() {
                        emailControllers.add({
                          'address': TextEditingController(),
                          'label': TextEditingController(),
                        });
                      });
                    },
                  )
                ],
              )
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => widget.onSave(context, {
          'androidUID': widget.initialContactData?['androidUID'],
          'iosUID': widget.initialContactData?['iosUID'],
          'firebaseUID': widget.initialContactData?['firebaseUID'],
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

      await controller.editContact(contactData);
      
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
}
