import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfile extends StatefulWidget {
  const UserProfile({super.key});

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  // Form controllers for login/signup
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  
  // Authentication instance
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Track if we're in signup mode
  bool _isSignup = false;
  
  // Loading state
  bool _isLoading = false;
  
  // Error message
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // Login with email and password
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'An error occurred during login';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Sign up with email and password
  Future<void> _signup() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Create the user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      // Update the user's display name
      await userCredential.user?.updateDisplayName(_nameController.text.trim());
      
      // Reload user to get updated info
      await userCredential.user?.reload();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'An error occurred during signup';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Sign out
  Future<void> _signOut() async {
    await _auth.signOut();
    setState(() {}); // Refresh UI
  }

  // Auth form
  Widget _buildAuthForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isSignup)
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
          if (_isSignup)
            const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 24),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ElevatedButton(
            onPressed: _isLoading ? null : (_isSignup ? _signup : _login),
            child: _isLoading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isSignup ? 'Sign Up' : 'Login'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _isSignup = !_isSignup;
                _errorMessage = null;
              });
            },
            child: Text(_isSignup
                ? 'Already have an account? Login'
                : 'Don\'t have an account? Sign Up'),
          ),
        ],
      ),
    );
  }

  // User profile information display
  Widget _buildUserInfo(User user) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 50,
            child: Icon(Icons.person, size: 50),
          ),
          const SizedBox(height: 16),
          Text(
            user.displayName ?? 'No name provided',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            user.email ?? 'No email provided',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _signOut,
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final user = snapshot.data;
        
        if (user != null) {
          // User is logged in, show profile
          return _buildUserInfo(user);
        } else {
          // User is not logged in, show auth form
          return _buildAuthForm();
        }
      },
    );
  }
}