class DriverSession {
  const DriverSession({
    required this.phone,
    required this.loggedIn,
  });

  final String phone;
  final bool loggedIn;

  DriverSession copyWith({String? phone, bool? loggedIn}) {
    return DriverSession(
      phone: phone ?? this.phone,
      loggedIn: loggedIn ?? this.loggedIn,
    );
  }
}
