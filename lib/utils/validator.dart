// Email validator
String? validateEmail(String? value) {
  if (value == null || value.isEmpty) {
    return 'Email is required';
  }
  
  // Check email format using regex
  final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  if (!emailRegExp.hasMatch(value)) {
    return 'Please enter a valid email address';
  }
  
  return null;
}

// Password validator
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Password is required';
  }
  
  if (value.length < 6) {
    return 'Password must be at least 6 characters';
  }
  
  return null;
}

// Confirm password validator factory
Function(String?) validateConfirmPassword(String password) {
  return (String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    
    if (value != password) {
      return 'Passwords do not match';
    }
    
    return null;
  };
}

// Name validator
String? validateName(String? value) {
  if (value == null || value.isEmpty) {
    return 'Name is required';
  }
  
  if (value.length < 2) {
    return 'Name must be at least 2 characters';
  }
  
  return null;
}

// Phone validator
String? validatePhone(String? value) {
  if (value == null || value.isEmpty) {
    return 'Phone number is required';
  }
  
  // Basic phone validation (can be improved for different formats)
  final phoneRegExp = RegExp(r'^\+?[0-9]{10,15}$');
  if (!phoneRegExp.hasMatch(value)) {
    return 'Please enter a valid phone number';
  }
  
  return null;
}