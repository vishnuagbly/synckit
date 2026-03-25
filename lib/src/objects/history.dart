class History {
  DateTime? lastSyncWithNetworkFetchTime;

  History({this.lastSyncWithNetworkFetchTime});

  void updateLastSyncWithNetworkFetchTime() {
    lastSyncWithNetworkFetchTime = DateTime.now();
  }

  History copyWith({DateTime? lastSyncWithNetworkFetchTime}) {
    return History(
      lastSyncWithNetworkFetchTime:
          lastSyncWithNetworkFetchTime ?? this.lastSyncWithNetworkFetchTime,
    );
  }
}
