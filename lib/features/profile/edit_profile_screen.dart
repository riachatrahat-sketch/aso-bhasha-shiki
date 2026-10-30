import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/json_helpers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/state_views.dart';
import '../../providers/providers.dart';
import '../auth/auth_layout.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  static const _genders = ['Male', 'Female', 'Prefer not to say'];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  String? _gender;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save(String uid) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile(
            uid,
            fullName: _name.text,
            gender: _gender!,
          );
      if (!mounted) return;
      showMessage(context, 'Profile updated.');
      context.pop();
    } on AppException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final uid = ref.watch(uidProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: profileAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => const ErrorView(message: 'Could not load your profile.'),
        data: (profile) {
          if (profile == null || uid == null) {
            return const ErrorView(message: 'Profile not found.');
          }
          if (!_loaded) {
            _name.text = profile.fullName;
            _gender = _genders.contains(profile.gender) ? profile.gender : 'Prefer not to say';
            _loaded = true;
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: Validators.fullName,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      initialValue: profile.email,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        helperText: 'Email cannot be changed here.',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: [
                        for (final g in _genders) DropdownMenuItem(value: g, child: Text(g)),
                      ],
                      onChanged: (v) => setState(() => _gender = v),
                      validator: Validators.gender,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    LoadingButton(
                      label: 'Save changes',
                      loading: _saving,
                      onPressed: () => _save(uid),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
