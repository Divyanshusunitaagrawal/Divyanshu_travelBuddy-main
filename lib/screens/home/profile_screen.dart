import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:travelcompanion/config/theme.dart';
import 'package:travelcompanion/models/user_model.dart';
import 'package:travelcompanion/services/auth_service.dart';
import 'package:travelcompanion/services/firestore_service.dart';
import 'package:travelcompanion/services/storage_service.dart';
import 'package:travelcompanion/utils/validator.dart';
import 'package:travelcompanion/widgets/common/error_dialog.dart';
import 'package:travelcompanion/widgets/common/loading_indicator.dart';


class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = true;
  bool _isSaving = false;
  UserModel? _user;
  File? _imageFile;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _interestController = TextEditingController();
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _interestController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userData = await _firestoreService.getCurrentUserData();
      
      if (userData != null) {
        setState(() {
          _user = userData;
          _nameController.text = userData.name ?? '';
          _bioController.text = userData.bio ?? '';
          _phoneController.text = userData.phone ?? '';
          _interestController.text = userData.interest ?? '';
        });
      }
    } catch (e) {
      showErrorDialog(
        context: context,
        title: 'Error',
        message: 'Failed to load user data: $e',
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      showErrorDialog(
        context: context,
        title: 'Image Error',
        message: 'Failed to pick image: $e',
      );
    }
  }
  
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      String? profilePicUrl = _user?.profilePic;
      
      // Upload new image if selected
      if (_imageFile != null) {
        profilePicUrl = await _storageService.uploadProfileImage(
          _imageFile!,
          'profile_images/${Provider.of<AuthService>(context, listen: false).currentUser?.uid}',
        );
      }
      
      // Update user data
      await _firestoreService.updateCurrentUserData({
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'phone': _phoneController.text.trim(),
        'interest': _interestController.text.trim(),
        'profilePic': profilePicUrl,
      });
      
      // Update user display name in Firebase Auth
      await Provider.of<AuthService>(context, listen: false).updateUserProfile(
        displayName: _nameController.text.trim(),
        photoURL: profilePicUrl,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: AppTheme.accentColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: EdgeInsets.all(10),
        ),
      );
      
      // Refresh user data
      _loadUserData();
    } catch (e) {
      showErrorDialog(
        context: context,
        title: 'Update Error',
        message: 'Failed to update profile: $e',
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
  
  Future<void> _signOut() async {
    try {
      // Set user as inactive
      await _firestoreService.updateCurrentUserData({
        'isActive': false,
      });
      
      // Sign out
      await Provider.of<AuthService>(context, listen: false).signOut();
    } catch (e) {
      showErrorDialog(
        context: context,
        title: 'Sign Out Error',
        message: 'Failed to sign out: $e',
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('My Profile'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: LoadingIndicator(message: 'Loading profile...'))
          : Padding(
            padding: EdgeInsets.only(bottom: 90), // Enough space for the nav bar
            child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile image
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: _imageFile != null
                                    ? FileImage(_imageFile!) as ImageProvider
                                    : _user?.profilePic != null
                                        ? NetworkImage(_user!.profilePic!) as ImageProvider
                                        : null,
                                child: (_imageFile == null && (_user?.profilePic == null || _user!.profilePic!.isEmpty))
                                    ? Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.grey[400],
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.primaryColor,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 5,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.link, color: Colors.white),
                                    onPressed: () async {
                                    final urlController = TextEditingController();
                                    await showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                      title: Text('Enter Image URL'),
                                      content: TextField(
                                        controller: urlController,
                                        decoration: InputDecoration(
                                        hintText: 'Paste image URL here',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                          final newUrl = urlController.text.trim();
                                          if (newUrl.isNotEmpty) {
                                            try {
                                            await _firestoreService.updateCurrentUserData({
                                              'profilePic': newUrl,
                                            });
                                            setState(() {
                                              _user = _user?.copyWith(profilePic: newUrl);
                                            });
                                            Navigator.of(context).pop();
                                            } catch (e) {
                                            showErrorDialog(
                                              context: context,
                                              title: 'Error',
                                              message: 'Failed to update profile picture: $e',
                                            );
                                            }
                                          } else {
                                            Navigator.of(context).pop();
                                          }
                                          },
                                        child: Text('Save'),
                                        ),
                                      ],
                                      ),
                                    );
                                    },
                                    constraints: BoxConstraints.tightFor(
                                    width: 40,
                                    height: 40,
                                    ),
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Change profile picture via URL',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),
                        
                        // Name field
                        Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: AppTheme.inputDecoration(
                            labelText: 'Full Name',
                            hintText: 'Enter your full name',
                            prefixIcon: Icons.person_outline,
                          ),
                          validator: validateName,
                        ),
                        SizedBox(height: 16),
                        
                        // Phone field
                        TextFormField(
                          controller: _phoneController,
                          decoration: AppTheme.inputDecoration(
                            labelText: 'Phone Number',
                            hintText: 'Enter your phone number',
                            prefixIcon: Icons.phone_outlined,
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        SizedBox(height: 24),
                        
                        // Travel preferences
                        Text(
                          'Travel Preferences',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _interestController,
                          decoration: AppTheme.inputDecoration(
                            labelText: 'Travel Interests',
                            hintText: 'E.g., Hiking, Photography, Food',
                            prefixIcon: Icons.interests,
                          ),
                        ),
                        SizedBox(height: 16),
                        
                        // Bio field
                        TextFormField(
                          controller: _bioController,
                          decoration: AppTheme.inputDecoration(
                            labelText: 'Bio',
                            hintText: 'Tell others about yourself...',
                            prefixIcon: Icons.description_outlined,
                          ),
                          maxLines: 3,
                        ),
                        SizedBox(height: 32),
                        
                        // Save button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveProfile,
                            style: AppTheme.primaryButtonStyle(),
                            child: _isSaving
                                ? LoadingIndicator(size: 24)
                                : Text(
                                    'Save Profile',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ),
    );
  }
}