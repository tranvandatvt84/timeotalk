import 'package:flutter/material.dart';
import 'package:timeotalk/features/contacts/models/invitation_model.dart';
import 'package:timeotalk/features/contacts/repositories/contacts_repository.dart';
import 'package:timeotalk/features/contacts/viewmodels/contacts_view_model.dart';

class InvitationsView extends StatefulWidget {
  const InvitationsView({super.key, ContactsViewModel? viewModel})
    : _viewModel = viewModel;

  final ContactsViewModel? _viewModel;

  @override
  State<InvitationsView> createState() => _InvitationsViewState();
}

class _InvitationsViewState extends State<InvitationsView> {
  late final ContactsViewModel _viewModel;
  late final bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget._viewModel == null;
    _viewModel =
        widget._viewModel ??
        ContactsViewModel(repository: SupabaseContactsRepository());
    if (_ownsViewModel) {
      Future.microtask(_viewModel.load);
    }
  }

  @override
  void dispose() {
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invitations')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _viewModel,
          builder: (context, _) {
            final state = _viewModel.state;

            if (state.isLoading && state.invitations.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return RefreshIndicator(
              onRefresh: _viewModel.load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (state.errorMessage != null) ...[
                    Text(
                      state.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  for (final invitation in state.invitations)
                    _InvitationTile(
                      invitation: invitation,
                      isLoading: state.isLoading,
                      onAccept: () =>
                          _viewModel.acceptInvitation(invitation.id),
                      onDecline: () =>
                          _viewModel.declineInvitation(invitation.id),
                    ),
                  if (state.invitations.isEmpty)
                    const ListTile(
                      leading: Icon(Icons.mail_outline),
                      title: Text('No invitations'),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InvitationTile extends StatelessWidget {
  const _InvitationTile({
    required this.invitation,
    required this.isLoading,
    required this.onAccept,
    required this.onDecline,
  });

  final InvitationModel invitation;
  final bool isLoading;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final isPending = invitation.status == 'pending';

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person_add_alt)),
      title: Text(invitation.senderId),
      subtitle: Text(invitation.message ?? invitation.status),
      trailing: isPending
          ? Wrap(
              spacing: 4,
              children: [
                IconButton(
                  tooltip: 'Accept',
                  onPressed: isLoading ? null : onAccept,
                  icon: const Icon(Icons.check),
                ),
                IconButton(
                  tooltip: 'Decline',
                  onPressed: isLoading ? null : onDecline,
                  icon: const Icon(Icons.close),
                ),
              ],
            )
          : Text(invitation.status),
    );
  }
}
