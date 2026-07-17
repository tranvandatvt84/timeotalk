import 'package:flutter_test/flutter_test.dart';
import 'package:timeotalk/features/contacts/models/contact_model.dart';

void main() {
  test('ContactModel parses joined contact profile display data', () {
    final contact = ContactModel.fromSupabaseRow(const {
      'id': 'contact_1',
      'owner_id': 'user_1',
      'contact_user_id': 'friend_1',
      'created_from_invitation_id': 'invitation_1',
      'nickname': null,
      'favorite_at': null,
      'blocked_at': null,
      'created_at': null,
      'updated_at': null,
      'contact_profile': {
        'display_name': 'Alex Rivera',
        'avatar_url': 'https://example.com/alex.png',
      },
    });

    expect(contact.displayName, 'Alex Rivera');
    expect(contact.avatarUrl, 'https://example.com/alex.png');
    expect(contact.contactUserId, 'friend_1');
  });
}
