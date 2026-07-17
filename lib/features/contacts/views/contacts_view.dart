import 'package:flutter/material.dart';
import 'package:timeotalk/features/contacts/models/contact_model.dart';
import 'package:timeotalk/features/contacts/repositories/contacts_repository.dart';
import 'package:timeotalk/features/contacts/viewmodels/contacts_view_model.dart';
import 'package:timeotalk/features/contacts/views/invitations_view.dart';

class ContactsView extends StatefulWidget {
  const ContactsView({super.key, ContactsViewModel? viewModel})
    : _viewModel = viewModel;

  final ContactsViewModel? _viewModel;

  @override
  State<ContactsView> createState() => _ContactsViewState();
}

class _ContactsViewState extends State<ContactsView> {
  final _receiverController = TextEditingController();
  final _messageController = TextEditingController();

  late final ContactsViewModel _viewModel;
  late final bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget._viewModel == null;
    _viewModel =
        widget._viewModel ??
        ContactsViewModel(repository: SupabaseContactsRepository());
    Future.microtask(_viewModel.load);
  }

  @override
  void dispose() {
    _receiverController.dispose();
    _messageController.dispose();
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
        key: const Key('contacts-view'),
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

              if (state.isLoading && state.contacts.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _viewModel.load,
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
                onRefresh: _viewModel.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                  children: [
                    _ContactsHeader(
                      pendingInvitationCount: state.invitations
                          .where((invitation) => invitation.status == 'pending')
                          .length,
                      onOpenInvitations: _openInvitations,
                    ),
                    const SizedBox(height: 24),
                    _InvitePanel(
                      receiverController: _receiverController,
                      messageController: _messageController,
                      isLoading: state.isLoading,
                      onSend: _sendInvitation,
                    ),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        state.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (state.contacts.isEmpty)
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.person_outline),
                        title: Text('No contacts yet'),
                      )
                    else
                      for (final contact in state.contacts)
                        _ContactTile(contact: contact),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openInvitations() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InvitationsView(viewModel: _viewModel)),
    );
  }

  Future<void> _sendInvitation() async {
    final receiverId = _receiverController.text.trim();
    if (receiverId.isEmpty) {
      return;
    }

    await _viewModel.sendInvitation(
      receiverId: receiverId,
      message: _messageController.text,
    );

    if (!mounted || _viewModel.state.errorMessage != null) {
      return;
    }

    _receiverController.clear();
    _messageController.clear();
  }
}

class _ContactsHeader extends StatelessWidget {
  const _ContactsHeader({
    required this.pendingInvitationCount,
    required this.onOpenInvitations,
  });

  final int pendingInvitationCount;
  final VoidCallback onOpenInvitations;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contacts',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pending invitations: $pendingInvitationCount',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          key: const Key('contacts-invitations-button'),
          tooltip: 'Invitations',
          onPressed: onOpenInvitations,
          icon: const Icon(Icons.mail_outline),
        ),
      ],
    );
  }
}

class _InvitePanel extends StatelessWidget {
  const _InvitePanel({
    required this.receiverController,
    required this.messageController,
    required this.isLoading,
    required this.onSend,
  });

  final TextEditingController receiverController;
  final TextEditingController messageController;
  final bool isLoading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('contacts-invite-receiver'),
          controller: receiverController,
          decoration: const InputDecoration(
            labelText: 'Profile ID',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_add_alt),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('contacts-invite-message'),
          controller: messageController,
          decoration: const InputDecoration(
            labelText: 'Message',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.chat_bubble_outline),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('contacts-send-invite'),
          onPressed: isLoading ? null : onSend,
          icon: const Icon(Icons.send),
          label: const Text('Send Invite'),
        ),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact});

  final ContactModel contact;

  @override
  Widget build(BuildContext context) {
    final title =
        contact.nickname ?? contact.displayName ?? contact.contactUserId;

    return ListTile(
      leading: CircleAvatar(child: Text(_initials(title))),
      title: Text(title),
      subtitle: Text(contact.contactUserId),
      trailing: IconButton(
        tooltip: 'Open chat',
        onPressed: () {},
        icon: const Icon(Icons.chat_bubble_outline),
      ),
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
