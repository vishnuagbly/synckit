import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings.g.dart';

/// Settings for collection-based network storage mode
class CollectionBasedSettings {
  final bool enabled;
  final bool getAllEnabled;
  final int maxGetAllDocs;

  const CollectionBasedSettings({
    this.enabled = false,
    this.getAllEnabled = true,
    this.maxGetAllDocs = 10,
  });

  CollectionBasedSettings copyWith({
    bool? enabled,
    bool? getAllEnabled,
    int? maxGetAllDocs,
  }) {
    return CollectionBasedSettings(
      enabled: enabled ?? this.enabled,
      getAllEnabled: getAllEnabled ?? this.getAllEnabled,
      maxGetAllDocs: maxGetAllDocs ?? this.maxGetAllDocs,
    );
  }
}

@riverpod
class CollectionSettings extends _$CollectionSettings {
  @override
  CollectionBasedSettings build() => const CollectionBasedSettings();

  void toggleCollectionBased() {
    state = state.copyWith(enabled: !state.enabled);
  }

  void setGetAllEnabled(bool value) {
    state = state.copyWith(getAllEnabled: value);
  }

  void setMaxGetAllDocs(int value) {
    state = state.copyWith(maxGetAllDocs: value);
  }

  void updateSettings(CollectionBasedSettings settings) {
    state = settings;
  }
}
