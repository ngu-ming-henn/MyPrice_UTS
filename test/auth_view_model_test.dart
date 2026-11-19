import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/services/auth_service.dart';
import 'package:smartshop/viewmodels/auth_view_model.dart';

class FakeUser implements User {
  FakeUser(this.uid);
  @override
  final String uid;
  @override
  String? get email => 'staff@test.com';
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeMetadata implements SnapshotMetadata {
  FakeMetadata({this.hasPendingWrites = false, this.isFromCache = false});
  @override
  final bool hasPendingWrites;
  @override
  final bool isFromCache;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// The profile document as Firestore reports it. A test fake, so the
// "do not implement" marker on DocumentSnapshot does not apply here.
// ignore: subtype_of_sealed_class
class FakeProfile implements DocumentSnapshot<Map<String, dynamic>> {
  FakeProfile({required this.exists, bool pending = false})
    : metadata = FakeMetadata(hasPendingWrites: pending);
  @override
  final bool exists;
  @override
  final SnapshotMetadata metadata;
  @override
  String get id => 'u1';
  @override
  Map<String, dynamic>? data() => exists
      ? {'name': 'Admin UTS', 'email': 'staff@test.com', 'role': 'staff'}
      : null;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeAuth implements AuthService {
  final users = StreamController<User?>.broadcast();
  final profile = StreamController<DocumentSnapshot<Map<String, dynamic>>>();
  @override
  Stream<User?> authStateChanges() => users.stream;
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserDoc(String uid) =>
      profile.stream;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('a refused "Join as staff" keeps the page (and its error)', () async {
    final auth = FakeAuth();
    final vm = AuthViewModel(auth);
    auth.users.add(FakeUser('u1'));
    await settle();
    auth.profile.add(FakeProfile(exists: false)); // server: no profile
    await settle();
    expect(vm.status, AuthStatus.profileMissing);

    final seen = <AuthStatus>[];
    vm.addListener(() => seen.add(vm.status));
    // Join: the phone shows the new profile at once, then the server
    // refuses it and Firestore rolls it back.
    auth.profile.add(FakeProfile(exists: true, pending: true));
    auth.profile.add(FakeProfile(exists: false));
    await settle();
    expect(seen, isEmpty); // no flash of the staff pages, no jump back
    expect(vm.status, AuthStatus.profileMissing);
  });

  test('an accepted join opens the staff side', () async {
    final auth = FakeAuth();
    final vm = AuthViewModel(auth);
    auth.users.add(FakeUser('u1'));
    await settle();
    auth.profile.add(FakeProfile(exists: false));
    auth.profile.add(FakeProfile(exists: true, pending: true));
    await settle();
    expect(vm.status, AuthStatus.profileMissing); // waiting for the server
    auth.profile.add(FakeProfile(exists: true)); // server accepted it
    await settle();
    expect(vm.status, AuthStatus.signedIn);
    expect(vm.isStaff, isTrue);
  });
}
