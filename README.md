# SyncKit

SyncKit is a Dart package designed to facilitate seamless synchronization of data between local storage and network storage. It provides a robust and flexible framework for managing data synchronization in Flutter applications.

## Features

- **Local and Network Storage**: Sync data between local storage (Hive) and network storage (Firestore).
- **Sorting and Filtering**: Configurable sorting and filtering of datasets.
- **Initialization Callbacks**: Custom initialization logic with callbacks.
- **Error Handling**: Comprehensive error handling for network and storage operations.
- **Riverpod Integration**: Easily integrate with Riverpod for state management.

## Getting Started

To start using SyncKit, run the following command:

```sh
flutter pub add synckit
```

This will add the latest version of SyncKit to your `pubspec.yaml` and install the package.

## Usage

### Basic Setup

1. **Define your data model**:

    ```dart
    class MyDataModel with StdObj {
      @override
      final String id;
      final String name;

      MyDataModel({required this.id, required this.name});

      @override
      Map<String, dynamic> toJson() => {'id': id, 'name': name};

      factory MyDataModel.fromJson(Map<String, dynamic> json) =>
          MyDataModel(id: json['id'], name: json['name']);
    }
    ```

2. **Initialize SyncManager**:

    ```dart
    final syncManager = SyncManager<MyDataModel>.fromStdObj(
      fromJson: MyDataModel.fromJson,
      storage: LocalStorage<MyDataModel>('my_data_box'),
      network: NetworkStorage<MyDataModel>('my_data_collection'),
    );
    ```

3. **Create SyncConfig**:

    ```dart
    final syncConfig = SyncConfig<MyDataModel>(
      manager: syncManager,
      sortConfig: SortConfig(isSorted: true, comparator: (a, b) => a.name.compareTo(b.name)),
    );
    ```

4. **Use with Riverpod**:

    ```dart
    @riverpod
    class MyDataNotifier extends _$MyDataNotifier with SyncedState<MyDataModel> {
      @override
      MyDataModel build() {
        return initialize(syncConfig);
      }
    }
    ```

### Advanced Usage

- **Custom Initialization Callback**:

    ```dart
    syncConfig.initializeCallback = (state, obj) async {
      // Custom initialization logic
    };
    ```

- **Handling Errors**:

    ```dart
    try {
      await syncManager.update(data);
    } catch (e) {
      // Handle error
    }
    ```

## Additional Information

For more information, visit the [documentation](https://your-docs-link.com). Contributions are welcome! Please see the [contributing guidelines](https://your-contributing-link.com) for more details. If you encounter any issues, please file them [here](https://your-issues-link.com).
