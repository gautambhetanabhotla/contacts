import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Contact {
  final Map<String, dynamic> data;

  const Contact({
    required this.data,
  });

  dynamic operator [](String key) => data[key];

  String getLeadingCharacter() {
    // data["firstName"].isNotEmpty ? contact["firstName"][0] : (contact["lastName"].isNotEmpty ? contact["lastName"][0] : 'U')
    String? fn = data["First name"] as String?;
    if (fn != null && fn.isNotEmpty) return fn[0];
    String? ln = data["Last name"] as String?;
    if (ln != null && ln.isNotEmpty) return ln[0];
    String? mn = data["Middle name"] as String?;
    if (mn != null && mn.isNotEmpty) return mn[0];
    return '?';
  }

  @override
  String toString() {
    return 'Contact{data: $data}';
  }
  
  factory Contact.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Contact(
      data: data,
    );
  }

  /// Update contact data by **overriding** existing data with `contactData`.
  Future<void> set(Map<String, dynamic> contactData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .doc(contactData["id"])
          .set(contactData);
    }
  }

  /// Update contact data by **merging** existing data with `contactData`.
  Future<void> update(Map<String, dynamic> contactData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .doc(contactData["id"])
          .update(contactData);
    }
  }
}

class ContactsController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late Stream<QuerySnapshot> contactsStream;
  
  ContactsController() {
    final user = _auth.currentUser;
    // print(user?.uid);
    if (user != null) {
      contactsStream = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('contacts')
        .snapshots();
    }
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
}