import 'package:flutter_test/flutter_test.dart';
import 'package:unmute/models/channel_list.dart';

void main() {
  test('ranges expand low to high and drop duplicates', () {
    expect(parseChannelList('4-1, 2, 8'), [1, 2, 3, 4, 8]);
    expect(formatChannelList([1, 2, 3, 8]), '1-3, 8');
    expect(parseChannelList(''), isEmpty);
  });

  test('rejects junk and channels outside 1-32', () {
    expect(() => parseChannelList('Pastor'), throwsFormatException);
    expect(() => parseChannelList('1-40'), throwsFormatException);
    expect(() => parseChannelList('0'), throwsFormatException);
  });
}
