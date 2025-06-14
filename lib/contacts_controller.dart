import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
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
    final uids = [androidUID, iosUID, firebaseUID]
        .where((uid) => uid != null)
        .toList()
      ..sort();
    
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
    return 'Contact(androidUID: $androidUID, iosUID: $iosUID, firebaseUID: $firebaseUID, name: $fullName)';
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
        'jobTitle': org.title,
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
}

class ContactsController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late StreamController<List<Contact>> _contactsStreamController;
  Stream<List<Contact>> get contactsStream => _contactsStreamController.stream;

  List<Contact> _localContacts = [];
  List<Contact> _firebaseContacts = [];
  StreamSubscription<QuerySnapshot>? _firebaseSubscription;
  StreamSubscription<User?>? _authSubscription;

  // Platform support flags
  bool get supportsLocalContacts => Platform.isAndroid || Platform.isIOS;

  ContactsController() {
    _contactsStreamController = StreamController<List<Contact>>.broadcast(
      onListen: () {
        _emitMergedContacts();
      }
    );
    _authSubscription = _auth.authStateChanges().listen((user) {
      _initializeFirebaseStream();
    });
    _initializeStreams();
  }

  void _initializeFirebaseStream() {
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
        _emitMergedContacts();
      });
    }
  }

  void _initializeStreams() async {
    _initializeFirebaseStream();

    // Initialize local contacts only on supported platforms
    if (supportsLocalContacts) {
      await _loadLocalContacts();
      
      // Set up listener for local contact changes
      fc.FlutterContacts.addListener(_onLocalContactsChanged);
    }
  }

  Future<void> _loadLocalContacts() async {
    // Only attempt to load local contacts on supported platforms
    if (!supportsLocalContacts) return;
    
    try {
      if (await fc.FlutterContacts.requestPermission()) {
        final contacts = await fc.FlutterContacts.getContacts(withProperties: true);
        _localContacts = contacts.map((contact) => Contact.fromFlutterContact(contact)).toList();
        _emitMergedContacts();
      }
    } catch (e) {
      // Handle platform-specific errors gracefully
      talker.error('Error loading local contacts: $e');
      _localContacts = [];
      _emitMergedContacts();
    }
  }

  void _onLocalContactsChanged() {
    if (supportsLocalContacts) {
      _loadLocalContacts();
    }
  }

  /// Obtains latest contacts from both local and Firebase sources,
  /// merges them, and emits the result.
  /// This method is called whenever local contacts change or Firebase contacts update.
  /// It ensures that the stream always has the most up-to-date contact list.
  void _emitMergedContacts() {
    final mergedContacts = _mergeContacts(_localContacts, _firebaseContacts);
    talker.debug("Merged contacts: $mergedContacts");
    talker.debug("Local contacts: $_localContacts");
    talker.debug("Firebase contacts: $_firebaseContacts");
    _contactsStreamController.add(mergedContacts);
  }

  List<Contact> _mergeContacts(List<Contact> local, List<Contact> firebase) {
    final Map<Contact, Contact> contactMap = {}; // To map contacts by their UIDs
    
    // Add Firebase contacts first
    for (final contact in firebase) {
      contactMap[contact] = contact;
    }
    
    // Add local contacts only if platform supports them
    for (final contact in local) {
      final existingContact = contactMap[contact];

      if (existingContact != null) {
        // Both local and Firebase contact exist - merge based on lastModified timestamp
        final localTimestamp = contact.data['lastModified'] as int? ?? 0;
        final firebaseTimestamp = existingContact.data['lastModified'] as int? ?? 0;

        // Start with the most recently modified contact's data
        final isLocalNewer = localTimestamp >= firebaseTimestamp;
        final mergedData = Map<String, dynamic>.from(
          isLocalNewer ? contact.data : existingContact.data,
        );

        // Merge fields from the older contact if not present in the newer one
        final Map<String, dynamic> olderData =
        isLocalNewer ? existingContact.data : contact.data;
        for (final entry in olderData.entries) {
          if (!mergedData.containsKey(entry.key) || mergedData[entry.key] == null) {
        mergedData[entry.key] = entry.value;
          }
        }

        // Always preserve all UIDs if present
        if (contact.androidUID != null) mergedData['androidUID'] = contact.androidUID;
        if (existingContact.androidUID != null) mergedData['androidUID'] = existingContact.androidUID;
        if (contact.iosUID != null) mergedData['iosUID'] = contact.iosUID;
        if (existingContact.iosUID != null) mergedData['iosUID'] = existingContact.iosUID;
        if (contact.firebaseUID != null) mergedData['firebaseUID'] = contact.firebaseUID;
        if (existingContact.firebaseUID != null) mergedData['firebaseUID'] = existingContact.firebaseUID;

        contactMap[contact] = Contact(data: mergedData);
      } else {
        // Only local contact
        contactMap[contact] = contact;
      }
    }
    
    return contactMap.values.toList();
  }

  Future<void> addContact(Map<String, dynamic> contactData) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .add(contactData);
    }
  }

  Future<void> updateContact(String contactId, Map<String, dynamic> updatedData) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .doc(contactId)
          .update(updatedData);
    }
  }

  Future<void> deleteContact(String contactId) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .doc(contactId)
          .delete();
    }
  }

  void dispose() {
    _authSubscription?.cancel();
    _firebaseSubscription?.cancel();
    if (supportsLocalContacts) {
      fc.FlutterContacts.removeListener(_onLocalContactsChanged);
    }
    _contactsStreamController.close();
  }
}