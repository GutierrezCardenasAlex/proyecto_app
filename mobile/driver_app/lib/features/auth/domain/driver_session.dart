class DriverSession {
  const DriverSession({
    required this.userId,
    required this.driverId,
    required this.phone,
    required this.fullName,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.address,
    required this.token,
    required this.otpRequested,
    required this.loggedIn,
    required this.profileCompleted,
    required this.isLoading,
    required this.errorMessage,
    required this.isRestoring,
  });

  final String userId;
  final String driverId;
  final String phone;
  final String fullName;
  final String firstName;
  final String lastName;
  final String email;
  final String address;
  final String token;
  final bool otpRequested;
  final bool loggedIn;
  final bool profileCompleted;
  final bool isLoading;
  final String? errorMessage;
  final bool isRestoring;

  DriverSession copyWith({
    String? userId,
    String? driverId,
    String? phone,
    String? fullName,
    String? firstName,
    String? lastName,
    String? email,
    String? address,
    String? token,
    bool? otpRequested,
    bool? loggedIn,
    bool? profileCompleted,
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
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      address: address ?? this.address,
      token: token ?? this.token,
      otpRequested: otpRequested ?? this.otpRequested,
      loggedIn: loggedIn ?? this.loggedIn,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isRestoring: isRestoring ?? this.isRestoring,
    );
  }
}
