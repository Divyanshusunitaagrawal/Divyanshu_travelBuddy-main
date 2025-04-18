import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  Future<String> uploadProfileImage(File file, String path) async {
    try {
      final ref = _storage.ref().child(path);
      
      // Upload the file
      final uploadTask = ref.putFile(file);
      
      // Get download URL
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      throw 'Failed to upload image: $e';
    }
  }
  
  Future<void> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      throw 'Failed to delete file: $e';
    }
  }
}