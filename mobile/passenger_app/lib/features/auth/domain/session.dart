class Session {
  const Session({
    required this.userId,
    required this.phone,
    required this.fullName,
    required this.token,
    required this.otpRequested,
    required this.isAuthenticated,
    required this.isLoading,
    required this.errorMessage,
    required this.isRestoring,
  });

  final String userId;
  final String phone;
  final String fullName;
  final String token;
  final bool otpRequested;
  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;
  final bool isRestoring;

  Session copyWith({
    String? userId,
    String? phone,
    String? fullName,
    String? token,
    bool? otpRequested,
    bool? isAuthenticated,
    bool? isLoading,
    String? errorMessage,
    bool? isRestoring,
    bool clearError = false,
  }) {
    return Session(
      userId: userId ?? this.userId,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      token: token ?? this.token,
      otpRequested: otpRequested ?? this.otpRequested,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isRestoring: isRestoring ?? this.isRestoring,
    );
  }
}
