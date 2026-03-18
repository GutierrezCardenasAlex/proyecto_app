class DriverSession {
  const DriverSession({
    required this.phone,
    required this.loggedIn,
    required this.isLoading,
    required this.errorMessage,
  });

  final String phone;
  final bool loggedIn;
  final bool isLoading;
  final String? errorMessage;

  DriverSession copyWith({
    String? phone,
    bool? loggedIn,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DriverSession(
      phone: phone ?? this.phone,
      loggedIn: loggedIn ?? this.loggedIn,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
