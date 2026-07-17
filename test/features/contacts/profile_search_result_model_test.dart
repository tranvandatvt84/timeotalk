import 'package:flutter_test/flutter_test.dart';
import 'package:timeotalk/features/contacts/models/profile_search_result_model.dart';

void main() {
  test(
    'ProfileSearchResultModel parses and serializes profile search data',
    () {
      final result = ProfileSearchResultModel.fromJson(const {
        'id': 'profile_1',
        'display_name': 'Alex Rivera',
        'handle': 'alex',
        'avatar_url': 'https://example.com/avatar.png',
      });

      expect(result.id, 'profile_1');
      expect(result.displayName, 'Alex Rivera');
      expect(result.handle, 'alex');
      expect(result.avatarUrl, 'https://example.com/avatar.png');
      expect(result.toJson(), {
        'id': 'profile_1',
        'display_name': 'Alex Rivera',
        'handle': 'alex',
        'avatar_url': 'https://example.com/avatar.png',
      });
    },
  );

  test('ProfileSearchResultModel accepts profiles without handles', () {
    final result = ProfileSearchResultModel.fromJson(const {
      'id': 'profile_2',
      'display_name': 'Mia Chen',
      'handle': null,
      'avatar_url': null,
    });

    expect(result.id, 'profile_2');
    expect(result.displayName, 'Mia Chen');
    expect(result.handle, isNull);
    expect(result.avatarUrl, isNull);
    expect(result.toJson(), {'id': 'profile_2', 'display_name': 'Mia Chen'});
  });
}
