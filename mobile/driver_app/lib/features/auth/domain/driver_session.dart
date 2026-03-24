class DriverSession {
  const DriverSession({
    required this.userId,
    required this.driverId,
    required this.phone,
    required this.fullName,
    required this.token,
    required this.otpRequested,
    required this.loggedIn,
    required this.isLoading,
    required this.errorMessage,
    required this.isRestoring,
  });

  final String userId;
  final String driverId;
  final String phone;
  final String fullName;
  final String token;
  final bool otpRequested;
  final bool loggedIn;
  final bool isLoading;
  final String? errorMessage;
  final bool isRestoring;

  DriverSession copyWith({
    String? userId,
    String? driverId,
    String? phone,
    String? fullName,
    String? token,
    bool? otpRequested,
    bool? loggedIn,
    bool? isLoading,
    String? errorMessage,
    bool? isRestoring,
    bool clearError = false,
  }) {
    return DriverSession(
      userId: userId ?? this.userId,
      driverId: driverId ?? this.driverId,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      token: token ?? this.token,
      otpRequested: otpRequested ?? this.otpRequested,
      loggedIn: loggedIn ?? this.loggedIn,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isRestoring: isRestoring ?? this.isRestoring,
    );
  }
}
