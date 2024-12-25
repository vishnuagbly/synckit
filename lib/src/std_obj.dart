typedef ToJsonFn<T> = Map<String, dynamic> Function(T obj);
typedef GetIdFn<T> = String Function(T obj);
typedef FromJson<T> = T Function(Map<String, dynamic> json);

mixin StdObj {
  String get id;

  Map<String, dynamic> toJson();
}

class StdObjParams<T> {
  final ToJsonFn<T> toJson;
  final FromJson<T> fromJson;
  final GetIdFn<T> getId;

  StdObjParams({
    ToJsonFn<T>? toJson,
    GetIdFn<T>? getId,
    required this.fromJson,
  })  : toJson = toJson ?? ((obj) => (obj as StdObj).toJson()),
        getId = getId ?? ((obj) => (obj as StdObj).id);
}
