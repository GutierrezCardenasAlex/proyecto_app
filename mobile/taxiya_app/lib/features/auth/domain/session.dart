class Session {
  const Session({
    required this.userId,
    required this.phone,
    required this.fullName,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.address,
    required this.token,
    required this.otpRequested,
    required this.isAuthenticated,
    required this.profileCompleted,
    required this.deviceStatus,
    required this.completedTripCount,
    required this.freeTripCredits,
    required this.isLoading,
    required this.errorMessage,
    required this.isRestoring,
  });

  final String userId;
  final String phone;
  final String fullName;
  final String firstName;
  final String lastName;
  final String email;
  final String address;
  final String token;
  final bool otpRequested;
  final bool isAuthenticated;
  final bool profileCompleted;
  final String deviceStatus;
  final int completedTripCount;
  final int freeTripCredits;
  final bool isLoading;
  final String? errorMessage;
  final bool isRestoring;

  Session copyWith({
    String? userId,
    String? phone,
    String? fullName,
    String? firstName,
    String? lastName,
    String? email,
    String? address,
    String? token,
    bool? otpRequested,
    bool? isAuthenticated,
    bool? profileCompleted,
    String? deviceStatus,
    int? completedTripCount,
    int? freeTripCredits,
    bool? isLoading,
    String? errorMessage,
    bool? isRestoring,
    bool clearError = false,
  }) {
    return Session(
      userId: userId ?? this.userId,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      address: address ?? this.address,
      token: token ?? this.token,
      otpRequested: otpRequested ?? this.otpRequested,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      deviceStatus: deviceStatus ?? this.deviceStatus,
      completedTripCount: completedTripCount ?? this.completedTripCount,
      freeTripCredits: freeTripCredits ?? this.freeTripCredits,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isRestoring: isRestoring ?? this.isRestoring,
    );
  }
}
