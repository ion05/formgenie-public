import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:formgenie/providers/form_provider.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../globals/globals.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onIndexChanged;
  final Function(String) onFormIdChanged;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.onFormIdChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      color: const Color(0xFF1A1A1A),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 20),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 16, 0, 16),
              child: Row(
                children: [
                  Text(
                    'FormGenie',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    onPressed: () {
                      onIndexChanged(4);
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: Icon(FontAwesomeIcons.clockRotateLeft),
                    iconSize: 20,
                    color: Colors.white.withOpacity(0.4),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () {
                      onFormIdChanged('');
                      onIndexChanged(0);
                      final formProvider = context.read<FormProvider>();
                      formProvider.clearForm();
                      formProvider.clearChatHistory();

                      // Add a small delay before showing the message
                      Future.delayed(Duration.zero, () {
                        formProvider.addChatMessage(
                          ChatMessage(
                            isUser: false,
                            message: formProvider.isExportedGoogle
                                ? 'Hello! I\'m FormGenie. I can help you analyze your form responses. For example: "What is the average rating for question 3?" or "How many people selected option A in question 2?"'
                                : Globals.getCurrentFormFirestoreId().isNotEmpty
                                    ? 'Hello! I\'m FormGenie. Tell me about the changes you want to make to the form. For example: "Modify question 3 to include this change"'
                                    : 'Hello! I\'m FormGenie. Tell me about the form you want to create. For example: "Create a dance class RSVP form"',
                            animate: true,
                            isNew: true,
                          ),
                        );
                      });
                    },
                    icon: const Icon(FontAwesomeIcons.plus),
                    iconSize: 20,
                    color: Colors.white.withOpacity(0.4),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _SidebarItem(
              icon: selectedIndex == 0 ? FontAwesomeIcons.solidComment : FontAwesomeIcons.comment,
              label: 'Chat',
              isSelected: selectedIndex == 0,
              onTap: () => onIndexChanged(0),
            ),
            _SidebarItem(
              icon: selectedIndex == 1 ? FontAwesomeIcons.solidPenToSquare : FontAwesomeIcons.penToSquare,
              label: 'Editor',
              isSelected: selectedIndex == 1,
              onTap: () => onIndexChanged(1),
            ),
            _SidebarItem(
              icon: selectedIndex == 2 ? FontAwesomeIcons.solidEye : FontAwesomeIcons.eye,
              label: 'Preview',
              isSelected: selectedIndex == 2,
              onTap: () => onIndexChanged(2),
            ),
            _SidebarItem(
              icon: selectedIndex == 3 ? FontAwesomeIcons.shareNodes : FontAwesomeIcons.shareNodes,
              label: 'Export',
              isSelected: selectedIndex == 3,
              onTap: () => onIndexChanged(3),
            ),
            Consumer<FormProvider>(
              builder: (context, formProvider, child) {
                final bool isExported = formProvider.formId.isNotEmpty && formProvider.isFormExported;
                return Column(
                  children: [
                    _SidebarItem(
                      icon: selectedIndex == 5 ? FontAwesomeIcons.chartLine : FontAwesomeIcons.chartLine,
                      label: 'Analytics',
                      isSelected: selectedIndex == 5,
                      onTap: isExported ? () => onIndexChanged(5) : null,
                      isDisabled: !isExported,
                    ),
                    _SidebarItem(
                      icon: selectedIndex == 6 ? FontAwesomeIcons.solidRectangleList : FontAwesomeIcons.rectangleList,
                      label: 'Responses',
                      isSelected: selectedIndex == 6,
                      onTap: isExported ? () => onIndexChanged(6) : null,
                      isDisabled: !isExported,
                    ),
                  ],
                );
              },
            ),
            const Spacer(),
            Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                if (authProvider.isSignedIn) {
                  return _buildProfileSection(context, authProvider);
                } else {
                  return _buildSignInButton(context, authProvider);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.currentUser!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 0, 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage(user.photoURL ?? 'https://avatars.githubusercontent.com/u/46714636?v=4'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                Text(
                  user.email ?? '',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            splashRadius: 9,
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => authProvider.signOut(),
            icon: const Icon(FontAwesomeIcons.rightFromBracket),
            iconSize: 20,
            color: Colors.white.withOpacity(0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInButton(BuildContext context, AuthProvider authProvider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        onPressed: () => authProvider.signInWithGoogle(),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B5CF6),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: const Icon(FontAwesomeIcons.google, color: Colors.white),
        label: const Text(
          'Sign in with Google',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isDisabled;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isDisabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? const Color(0xFF8B5CF6).withOpacity(0.3) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDisabled ? Colors.grey.withOpacity(0.5) : (isSelected ? Colors.white : Colors.grey),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isDisabled ? Colors.grey.withOpacity(0.5) : (isSelected ? Colors.white : Colors.grey),
                fontSize: 16,
              ),
            ),
            if (isDisabled) ...[
              const SizedBox(width: 8),
              Icon(
                FontAwesomeIcons.lock,
                color: Colors.grey.withOpacity(0.5),
                size: 12,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
