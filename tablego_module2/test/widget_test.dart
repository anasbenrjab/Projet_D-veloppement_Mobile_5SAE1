import 'package:flutter_test/flutter_test.dart';
import 'package:tablego/core/database/in_memory_store.dart';

void main() {
  test('Seeded menu contains dishes', () async {
    final dishes = await InMemoryStore.instance.query('dishes');
    expect(dishes, isNotEmpty);
  });
}
