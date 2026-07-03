part of '../driver_home_page.dart';

class DriverLoadingSplash extends StatefulWidget {
  const DriverLoadingSplash({super.key});

  @override
  State<DriverLoadingSplash> createState() => _DriverLoadingSplashState();
}

class _DriverLoadingSplashState extends State<DriverLoadingSplash> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    DriverStartupTrace.markSplashVisible();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E43D8),
      body: AnimatedOpacity(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        opacity: _opacity,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0F47E8),
                Color(0xFF0D39C5),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Image.asset(
                        'assets/images/driver_splash_initial.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation(Color(0xFFFFD034)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DriverLoginShell extends StatelessWidget {
  const DriverLoginShell({super.key});

  @override
  Widget build(BuildContext context) => const _DriverLoginShell();
}
