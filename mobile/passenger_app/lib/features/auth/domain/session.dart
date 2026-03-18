class Session {
  const Session({
    required this.phone,
    required this.otpRequested,
    required this.isAuthenticated,
  });

  final String phone;
  final bool otpRequested;
  final bool isAuthenticated;

  Session copyWith({
    String? phone,
    bool? otpRequested,
    bool? isAuthenticated,
  }) {
    return Session(
      phone: phone ?? this.phone,
      otpRequested: otpRequested ?? this.otpRequested,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}
