import 'package:flutter/material.dart';
import '/services/navigation_service.dart';
import '/services/users/signup/SignUp_Service.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import '/services/supabase/Storage/supabase_storage.dart';
import 'package:boot_app/services/users/User.dart';

class SignUp_Profile_Page extends StatefulWidget {
  const SignUp_Profile_Page({super.key});

  @override
  State<SignUp_Profile_Page> createState() => _SignUp_Profile_PageState();
}

class _SignUp_Profile_PageState extends State<SignUp_Profile_Page> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  bool _isLoading = false;
  bool _imageLoadError = false;
  String profilePicUrl =
      'https://www.pngfind.com/pngs/m/610-6104451_image-placeholder-png-user-profile-placeholder-image-png.png';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeader(colorScheme, textTheme),
              _buildProfileFields(colorScheme, textTheme),
              _buildFinishButton(colorScheme, textTheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(
                'boot-terminal ~ Unknown-User@hackathon',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            'Welcome to Boot!',
            style: textTheme.displayLarge?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Time to create your profile',
            style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileFields(ColorScheme colorScheme, TextTheme textTheme) {
    return Expanded(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: _imageLoadError
                        ? null
                        : NetworkImage(profilePicUrl),
                    onBackgroundImageError: (exception, stackTrace) {
                      setState(() {
                        _imageLoadError = true;
                      });
                    },
                    child: _imageLoadError
                        ? Icon(Icons.person, size: 60, color: Colors.grey[600])
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    await _handleUploadPic();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Symbols.upload, size: 20),
                      const SizedBox(width: 8),
                      Text('Upload Photo'),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _usernameController,
                  enabled: !_isLoading,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    hintText: 'Enter your username',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerLowest,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _bioController,
                  enabled: !_isLoading,
                  maxLines: 4,
                  minLines: 3,
                  onSubmitted: (_) => _handleSignUp(),
                  decoration: InputDecoration(
                    labelText: 'Bio',
                    hintText: 'Tell us about yourself...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerLowest,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinishButton(ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleSignUp,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Creating Profile...',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              : Text(
                  'Create Profile',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _handleUploadPic() async {
    try {
      setState(() {
        _isLoading = true;
        _imageLoadError = false;
      });

      String supabasePrivateUrl =
          await SupabaseStorageService.uploadFileWithPicker(
            bucket: 'Profiles',
            supabasePath: '${UserService.currentUser?.id}/profile_pic',
          );

      String? supabasePublicUrl = await SupabaseStorageService.getPublicUrl(
        bucket: 'Profiles',
        supabasePath: supabasePrivateUrl,
      );

      if (supabasePublicUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get public url for profile picture'),
          ),
        );
        return;
      }

      SignupService.signUpUser.profilePictureUrl = supabasePublicUrl;
      setState(() {
        profilePicUrl = supabasePublicUrl;
        _imageLoadError = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile picture uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload profile picture: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignUp() async {
    final username = _usernameController.text.trim();
    final bio = _bioController.text.trim();

    if (username.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter your username')));
      return;
    }

    if (bio.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter your bio')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      SignupService.signUpUser.username = username;
      SignupService.signUpUser.bio = bio;
      await SignupService.createProfile(SignupService.signUpUser);
      NavigationService.navigateTo(
        context: context,
        destination: 'home',
        colorScheme: Theme.of(context).colorScheme,
        textTheme: Theme.of(context).textTheme,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign up failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}
