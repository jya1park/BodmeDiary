/// 간단한 Result 타입. 리포지토리 반환값에 사용.
sealed class Result<T> {
  const Result();
  R when<R>({
    required R Function(T value) success,
    required R Function(String message, Object? error) failure,
  });
}

class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(String message, Object? error) failure,
  }) =>
      success(value);
}

class Failure<T> extends Result<T> {
  const Failure(this.message, [this.error]);
  final String message;
  final Object? error;

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(String message, Object? error) failure,
  }) =>
      failure(message, error);
}
