import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:hive/hive.dart';
import 'dart:async';
import 'dart:io';

import './talker.dart';

class Contact {
  final Map<String, dynamic> data;

  const Contact({
    required this.data,
  });

  // Identifier getters
  String? get androidUID => data['androidUID'] as String?;
  String? get iosUID => data['iosUID'] as String?;
  String? get firebaseUID => data['firebaseUID'] as String?;
  String get localUID => 
    Platform.isAndroid ? androidUID ?? '' : 
    Platform.isIOS ? iosUID ?? '' : '';

  // Computed properties based on identifiers and platform
  bool get isLocal {
    if (Platform.isAndroid) return androidUID != null;
    if (Platform.isIOS) return iosUID != null;
    return false; // Other platforms don't support local contacts
  }
  
  bool get isBackedUp => firebaseUID != null;

  // For using Contact as a map key
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Contact) return false;
    
    // Contacts are equal if they have at least one matching non-null UID
    return (androidUID != null && androidUID == other.androidUID) ||
         (iosUID != null && iosUID == other.iosUID) ||
         (firebaseUID != null && firebaseUID == other.firebaseUID);
  }

  @override
  int get hashCode {
    // Use the lexicographically smallest non-null UID as the primary hash
    final uids = [firebaseUID, androidUID, iosUID]
        .where((uid) => uid != null)
        .toList();
    
    if (uids.isEmpty) return identityHashCode(this);
    
    // Use the smallest UID as the primary hash component
    // This ensures contacts that share any UID will have related hashes
    return uids.first.hashCode;
  }

  dynamic operator [](String key) => data[key];

  String? get leadingCharacter {
    final String? firstName = data["name"]["first"] as String?;
    if (firstName != null && firstName.isNotEmpty) return firstName[0].toUpperCase();
    final String? lastName = data["name"]["last"] as String?;
    if (lastName != null && lastName.isNotEmpty) return lastName[0].toUpperCase();
    final String? middleName = data["name"]["middle"] as String?;
    if (middleName != null && middleName.isNotEmpty) return middleName[0].toUpperCase();
    return null;
  }

  String get fullName {
    final String? namePrefix = data["name"]["prefix"] as String?;
    final String? firstName = data["name"]["first"] as String?;
    final String? middleName = data["name"]["middle"] as String?;
    final String? lastName = data["name"]["last"] as String?;
    final String? nameSuffix = data["name"]["suffix"] as String?;
    
    return [namePrefix, firstName, middleName, lastName, nameSuffix]
        .where((element) => element != null && element.isNotEmpty)
        .join(' ');
  }

  String get displayName {
    final name = fullName;
    return name.isNotEmpty ? name : 'Unknown Contact';
  }

  @override
  String toString() {
    return 'Contact(androidUID: $androidUID, iosUID: $iosUID, firebaseUID: $firebaseUID, name: $fullName, last modified at: ${data['lastModified']})';
  }
  
  factory Contact.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Add firebaseUID to the data
    data['firebaseUID'] = doc.id;
    
    return Contact(data: data);
  }

  factory Contact.fromFlutterContact(fc.Contact contact) {
    final data = <String, dynamic>{
      'name': {
        'first': contact.name.first,
        'last': contact.name.last,
        'middle': contact.name.middle,
        'prefix': contact.name.prefix,
        'suffix': contact.name.suffix
      },
      'displayName': contact.displayName,
    };

    // Add platform-specific identifier
    if (Platform.isAndroid) {
      data['androidUID'] = contact.id;
    } else if (Platform.isIOS) {
      data['iosUID'] = contact.id;
    }

    // Add phone numbers
    if (contact.phones.isNotEmpty) {
      data['phones'] = contact.phones.map((phone) => {
        'number': phone.number,
        'label': phone.label.name,
        'normalizedNumber': phone.normalizedNumber,
      }).toList();
    }

    // Add emails
    if (contact.emails.isNotEmpty) {
      data['emails'] = contact.emails.map((email) => {
        'address': email.address,
        'label': email.label.name,
      }).toList();
    }

    // Add addresses if available
    if (contact.addresses.isNotEmpty) {
      data['addresses'] = contact.addresses.map((address) => {
        'street': address.street,
        'city': address.city,
        'state': address.state,
        'postalCode': address.postalCode,
        'country': address.country,
        'label': address.label.name,
        'formattedAddress': address.address,
      }).toList();
    }

    // Add organizations if available
    if (contact.organizations.isNotEmpty) {
      data['organizations'] = contact.organizations.map((org) => {
        'company': org.company,
        'title': org.title,
        'department': org.department,
      }).toList();
    }

    // Add websites if available
    if (contact.websites.isNotEmpty) {
      data['websites'] = contact.websites.map((website) => {
        'url': website.url,
        'label': website.label.name,
      }).toList();
    }

    // Add social media profiles if available
    if (contact.socialMedias.isNotEmpty) {
      data['socialMedias'] = contact.socialMedias.map((social) => {
        'label': social.label.name,
        'userName': social.userName,
      }).toList();
    }

    // Add birthday if available
    if (contact.events.isNotEmpty) {
      final birthdays = contact.events.where((event) => 
          event.label == fc.EventLabel.birthday).toList();
      if (birthdays.isNotEmpty) {
        data['birthday'] = {
          'year': birthdays.first.year,
          'month': birthdays.first.month,
          'day': birthdays.first.day,
        };
      }
    }

    // Add notes if available
    if (contact.notes.isNotEmpty) {
      data['notes'] = contact.notes.map((note) => note.note).join('\n');
    }

    return Contact(data: data);
  }

  fc.Contact toFlutterContact() {
    final name = data["name"] ?? {};
    final List phones = data["phones"] ?? [];
    final List emails = data["emails"] ?? [];
    final organizations = data["organizations"] ?? [];

    fc.PhoneLabel stringToPhoneLabel(String label) {
      if (label.isEmpty) return fc.PhoneLabel.mobile;
      final labelMap = {
        'assistant': fc.PhoneLabel.assistant,
        'callback': fc.PhoneLabel.callback,
        'car': fc.PhoneLabel.car,
        'companyMain': fc.PhoneLabel.companyMain,
        'faxHome': fc.PhoneLabel.faxHome,
        'faxOther': fc.PhoneLabel.faxOther,
        'faxWork': fc.PhoneLabel.faxWork,
        'home': fc.PhoneLabel.home,
        'iPhone': fc.PhoneLabel.iPhone,
        'isdn': fc.PhoneLabel.isdn,
        'main': fc.PhoneLabel.main,
        'mms': fc.PhoneLabel.mms,
        'mobile': fc.PhoneLabel.mobile,
        'pager': fc.PhoneLabel.pager,
        'radio': fc.PhoneLabel.radio,
        'school': fc.PhoneLabel.school,
        'telex': fc.PhoneLabel.telex,
        'ttyTtd': fc.PhoneLabel.ttyTtd,
        'work': fc.PhoneLabel.work,
        'workMobile': fc.PhoneLabel.workMobile,
        'workPager': fc.PhoneLabel.workPager,
        'other': fc.PhoneLabel.other,
      };
      return labelMap[label] ?? fc.PhoneLabel.custom;
    }

    fc.EmailLabel stringToEmailLabel(String label) {
      if (label.isEmpty) return fc.EmailLabel.other;
      final labelMap = {
        'home': fc.EmailLabel.home,
        'iCloud': fc.EmailLabel.iCloud,
        'mobile': fc.EmailLabel.mobile,
        'school': fc.EmailLabel.school,
        'work': fc.EmailLabel.work,
        'other': fc.EmailLabel.other,
        'custom': fc.EmailLabel.custom,
      };
      return labelMap[label] ?? fc.EmailLabel.custom;
    }

    return fc.Contact(
      id: localUID,
      name: fc.Name(
        first: name["first"] ?? '',
        last: name["last"] ?? '',
        middle: name["middle"] ?? '',
        prefix: name["prefix"] ?? '',
        suffix: name["suffix"] ?? '',
      ),
      phones: phones.map((phone) => fc.Phone(
        phone["number"] ?? '',
        label: stringToPhoneLabel(phone["label"] ?? ''),
        customLabel: phone["label"] ?? '',
      )).toList(),
      emails: emails.map((email) => fc.Email(
        email["address"] ?? '',
        label: stringToEmailLabel(email["label"] ?? ''),
        customLabel: email["label"] ?? '',
      )).toList(),
      // organizations: organizations.map((org) => fc.Organization(
      //   company: org["company"] ?? '',
      //   title: org["title"] ?? '',
      //   department: org["department"] ?? '',
      // )).toList(),
    );
  }
}

class ContactsController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late StreamController<List<Contact>> _contactsStreamController;
  Stream<List<Contact>> get contactsStream => _contactsStreamController.stream;

  List<Contact> _localContacts = [];
  List<Contact> _firebaseContacts = [];
  final Map<Contact, Contact> _mergedContacts = {};
  StreamSubscription<QuerySnapshot>? _firebaseSubscription;
  StreamSubscription<User?>? _authSubscription;

  Box<Map> get _contactDataBox => Hive.box<Map>('contact_data');
  
  // Platform support flags
  bool get supportsLocalContacts => Platform.isAndroid || Platform.isIOS;

  ContactsController._();

  static Future<ContactsController> create() async {
    final controller = ContactsController._();
    
    controller._contactsStreamController = StreamController<List<Contact>>.broadcast(
      onListen: () {
        // talker.info("new listener");
        controller._emitMergedContacts();
      }
    );
    
    controller._authSubscription = controller._auth.authStateChanges().listen((user) {
      controller._initializeFirebaseStream().then((_) {
        talker.info("Reloading firebase");
        controller._mergeContacts(controller._firebaseContacts);
        controller._emitMergedContacts();
      });
    });
    
    // Wait for initialization to complete
    await controller._initializeStreams();
    controller._mergeContacts(controller._localContacts);
    controller._mergeContacts(controller._firebaseContacts);
    
    return controller;
  }

  Future<void> _initializeFirebaseStream() async {
    talker.debug("Initializing Firebase contacts stream");
    _firebaseSubscription?.cancel();
    final user = _auth.currentUser;
    if (user != null) {
      _firebaseSubscription = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .snapshots()
          .listen((snapshot) {
            talker.debug(snapshot.docs);
            _firebaseContacts = snapshot.docs
            .map((doc) => Contact.fromFirestore(doc))
            .toList();
          });
      _firestore
        .collection('users')
        .doc(user.uid)
        .collection('contacts')
        .where('lastModified', isNull: true)
        .get()
        .then((snapshot) async {
          for (final doc in snapshot.docs) {
          await doc.reference.update({
            'lastModified': DateTime.now().millisecondsSinceEpoch,
          });
          }
        });
    }
  }

  Future<void> _initializeStreams() async {
    _initializeFirebaseStream();

    // Initialize local contacts only on supported platforms
    if (supportsLocalContacts) {
      await _loadLocalContacts();

      for (final contact in _localContacts) {
        if (_contactDataBox.get(contact.localUID) == null) {
          // If no mapping exists, create a new one
          _contactDataBox.put(contact.localUID, {
            'lastModified': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
      
      // Set up listener for local contact changes
      fc.FlutterContacts.addListener(_loadLocalContacts);
    }
  }

  Future<void> _loadLocalContacts() async {
    // Only attempt to load local contacts on supported platforms
    if (!supportsLocalContacts) return;
    
    try {
      if (await fc.FlutterContacts.requestPermission()) {
        final contacts = await fc.FlutterContacts.getContacts(
          withProperties: true,
          withThumbnail: true,
          withPhoto: true,
          withAccounts: true,
          withGroups: true,
        );
        _localContacts = contacts.map((contact) {
          final c = Contact.fromFlutterContact(contact);
          final mapping = _contactDataBox.get(c.localUID);
          c.data['firebaseUID'] = mapping?['firebaseUID'];
          c.data['lastModified'] = mapping?['lastModified'] ?? DateTime.now().millisecondsSinceEpoch;
          return c;
        }).toList();
        // _emitMergedContacts();
      }
    } catch (e) {
      // Handle platform-specific errors gracefully
      talker.error('Error loading local contacts: $e');
      _localContacts = [];
      // _emitMergedContacts();
    }
  }

  /// Emits the merged contacts to the stream.
  void _emitMergedContacts() {
    talker.debug(_mergedContacts.values.toList());
    _contactsStreamController.add(_mergedContacts.values.toList());
  }

  Contact _mergeContact(Contact contact1, Contact contact2) {
    // Start with contact1's data as base
    final mergedData = Map<String, dynamic>.from(contact1.data);
    
    // Merge data from contact2, preferring newer timestamps when available
    final contact1Timestamp = contact1.data['lastModified'] as int? ?? 0;
    final contact2Timestamp = contact2.data['lastModified'] as int? ?? 0;
    final isContact2Newer = contact2Timestamp > contact1Timestamp;
    
    // Merge all fields from contact2
    for (final entry in contact2.data.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Skip UID fields, we'll handle them separately
      if (key == 'androidUID' || key == 'iosUID' || key == 'firebaseUID') {
        continue;
      }
      
      // If key doesn't exist in merged data or contact2 is newer, use contact2's value
      if (!mergedData.containsKey(key) || mergedData[key] == null || (isContact2Newer && value != null) ) {
        mergedData[key] = value;
      }
    }
    
    // Always preserve all UIDs from both contacts
    if (contact1.androidUID != null) mergedData['androidUID'] = contact1.androidUID;
    if (contact2.androidUID != null) mergedData['androidUID'] = contact2.androidUID;
    if (contact1.iosUID != null) mergedData['iosUID'] = contact1.iosUID;
    if (contact2.iosUID != null) mergedData['iosUID'] = contact2.iosUID;
    if (contact1.firebaseUID != null) mergedData['firebaseUID'] = contact1.firebaseUID;
    if (contact2.firebaseUID != null) mergedData['firebaseUID'] = contact2.firebaseUID;

    mergedData['lastModified'] = mergedData['lastModified'] ?? DateTime.now().millisecondsSinceEpoch;
    
    return Contact(data: mergedData);
  }

  void _mergeContacts(List<Contact> contactList) {
    for (final contact in contactList) {
      if (_mergedContacts.containsKey(contact)) {
        // Contact already exists, merge with new one
        final existingContact = _mergedContacts[contact];
        _mergedContacts[contact] = _mergeContact(existingContact!, contact);
      } else {
        // Add new contact
        _mergedContacts[contact] = contact;
      }
    }
  }

  Future<void> addContact(Map<String, dynamic> contactData) async {
    final user = _auth.currentUser;
    late final String firebaseUID;
    
    final c = Contact(data: contactData);
    late final fc.Contact c2;
    try {
      c2 = await c.toFlutterContact().insert();
    } catch (e) {
      talker.error('Error inserting contact: $e');
      return;
    }
    if (user != null) {
      final docref = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .add(contactData);
      firebaseUID = docref.id;
    }
    final localUID = c2.id;
    c.data['androidUID'] = Platform.isAndroid ? localUID : null;
    c.data['iosUID'] = Platform.isIOS ? localUID : null;
    c.data['firebaseUID'] = firebaseUID;
    _mergeContacts([c]);
    _emitMergedContacts();
    // Update Hive mapping
    await _contactDataBox.put(localUID, {
      'firebaseUID': firebaseUID,
      'lastModified': c.data['lastModified'] ?? DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> editContact(Map<String, dynamic> updatedData) async {
    final c = Contact(data: updatedData);
    talker.debug(updatedData);
    final fc.Contact c2 = c.toFlutterContact();
    talker.debug(c);
    if (c.isLocal) await c2.update();
    final user = _auth.currentUser;
    if (user != null && c.isBackedUp) {
      await _firestore
      .collection('users')
      .doc(user.uid)
      .collection('contacts')
      .doc(c.firebaseUID)
      .update(updatedData);
    }
    // Update Hive mapping
    if (c.isLocal) {
      await _contactDataBox.put(c.localUID, {
        'firebaseUID': c.firebaseUID,
        'lastModified': c.data['lastModified'] ?? DateTime.now().millisecondsSinceEpoch,
      });
    }
    _mergeContacts([c]);
    _emitMergedContacts();
  }

  Future<void> deleteContact(Map<String, dynamic> contactData) async {
    // final user = _auth.currentUser;
    // if (user != null) {
    //   await _firestore
    //       .collection('users')
    //       .doc(user.uid)
    //       .collection('contacts')
    //       .doc(contactId)
    //       .delete();
    // }
  }

  void dispose() {
    _authSubscription?.cancel();
    _firebaseSubscription?.cancel();
    if (supportsLocalContacts) {
      fc.FlutterContacts.removeListener(_loadLocalContacts);
    }
    _contactsStreamController.close();
  }
}