class Session {
  const Session({
    required this.phone,
    required this.otpRequested,
    required this.isAuthenticated,
    required this.isLoading,
    required this.errorMessage,
  });

  final String phone;
  final bool otpRequested;
  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;

  Session copyWith({
    String? phone,
    bool? otpRequested,
    bool? isAuthenticated,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return Session(
      phone: phone ?? this.phone,
      otpRequested: otpRequested ?? this.otpRequested,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
