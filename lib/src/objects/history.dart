class History {
  final DateTime? lastSyncWithNetworkFetchTime;

  const History({this.lastSyncWithNetworkFetchTime});

  History updateLastSyncWithNetworkFetchTime() {
    return copyWith(lastSyncWithNetworkFetchTime: DateTime.now());
  }

  History copyWith({DateTime? lastSyncWithNetworkFetchTime}) {
    return History(
      lastSyncWithNetworkFetchTime:
          lastSyncWithNetworkFetchTime ?? this.lastSyncWithNetworkFetchTime,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is History &&
            other.lastSyncWithNetworkFetchTime ==
                lastSyncWithNetworkFetchTime;
  }

  @override
  int get hashCode => lastSyncWithNetworkFetchTime.hashCode;

  @override
  String toString() =>
      'History(lastSyncWithNetworkFetchTime: $lastSyncWithNetworkFetchTime)';
}
