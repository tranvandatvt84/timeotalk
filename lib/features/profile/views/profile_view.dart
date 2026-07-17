import 'dart:async';

import 'package:flutter/material.dart';
import 'package:timeotalk/features/profile/models/profile_model.dart';
import 'package:timeotalk/features/profile/repositories/profile_repository.dart';
import 'package:timeotalk/features/profile/viewmodels/profile_view_model.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key, ProfileViewModel? viewModel})
    : _viewModel = viewModel;

  final ProfileViewModel? _viewModel;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _displayNameController = TextEditingController();
  final _handleController = TextEditingController();
  final _statusController = TextEditingController();

  late final ProfileViewModel _viewModel;
  late final bool _ownsViewModel;
  String? _lastSyncedProfileSignature;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget._viewModel == null;
    _viewModel =
        widget._viewModel ??
        ProfileViewModel(repository: SupabaseProfileRepository());
    unawaited(_viewModel.loadProfile());
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _handleController.dispose();
    _statusController.dispose();
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        key: const Key('profile-view'),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF9FAFB), Color(0xFFEFF4F7)],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _viewModel,
            builder: (context, _) {
              final state = _viewModel.state;
              _syncControllers(state.profile);

              if (state.isLoading && state.profile == null) {
                return RefreshIndicator(
                  onRefresh: _viewModel.loadProfile,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                    children: const [
                      SizedBox(
                        height: 320,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _viewModel.loadProfile,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                  children: [
                    Text(
                      'Profile',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                    ),
                    const SizedBox(height: 24),
                    _ProfileHeader(profile: state.profile),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        state.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    if (state.didSave) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Saved',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextField(
                      key: const Key('profile-display-name'),
                      controller: _displayNameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('profile-handle'),
                      controller: _handleController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Handle',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('profile-status'),
                      controller: _statusController,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.chat_bubble_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: state.isSaving ? null : _saveProfile,
                      icon: state.isSaving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        state.isSaving ? 'Saving...' : 'Save Profile',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _syncControllers(ProfileModel? profile) {
    if (profile == null) {
      return;
    }

    final signature =
        '${profile.id}:${profile.displayName}:${profile.handle ?? ''}:${profile.status ?? ''}';
    if (_lastSyncedProfileSignature == signature) {
      return;
    }

    _displayNameController.text = profile.displayName;
    _handleController.text = profile.handle ?? '';
    _statusController.text = profile.status ?? '';
    _lastSyncedProfileSignature = signature;
  }

  Future<void> _saveProfile() {
    return _viewModel.updateProfile(
      displayName: _displayNameController.text,
      handle: _handleController.text,
      status: _statusController.text,
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final ProfileModel? profile;

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    if (profile == null) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text('No profile found'),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 38,
          backgroundImage: profile.avatarUrl == null
              ? null
              : NetworkImage(profile.avatarUrl!),
          child: profile.avatarUrl == null
              ? Text(
                  _initials(profile.displayName),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                profile.handle == null ? 'No handle yet' : '@${profile.handle}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                profile.status == null || profile.status!.isEmpty
                    ? 'No status yet'
                    : profile.status!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                profile.id,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _initials(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);

    if (words.isEmpty) {
      return '?';
    }

    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }
}
