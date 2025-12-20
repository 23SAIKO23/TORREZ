import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  final List<String> apiUrls = const [
    'http://127.0.0.1/puerto_evo',
    'http://localhost/puerto_evo',
    'http://192.168.0.224/puerto_evo',
  ];

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();

    _bootstrap();
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('device_id');
    if (existing != null && existing.trim().isNotEmpty) return existing;

    final id = const Uuid().v4();
    await prefs.setString('device_id', id);
    return id;
  }

  Future<void> _registerDevice(String deviceId) async {
    final payload = {
      'device_id': deviceId,
    };

    http.Response? lastResponse;
    Object? lastError;

    for (final base in apiUrls) {
      try {
        final res = await http
            .post(
              Uri.parse('$base/device_auth/device_register.php'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(payload),
            )
            .timeout(const Duration(seconds: 6));
        lastResponse = res;
        if (res.statusCode == 200) return;
      } catch (e) {
        lastError = e;
      }
    }

    final details = lastResponse != null
        ? 'HTTP ${lastResponse.statusCode}: ${lastResponse.body}'
        : (lastError?.toString() ?? 'unknown');
    throw Exception('device_register_failed: $details');
  }

  Future<String> _fetchDeviceStatus(String deviceId) async {
    http.Response? lastResponse;
    Object? lastError;

    for (final base in apiUrls) {
      try {
        final res = await http
            .get(
              Uri.parse('$base/device_auth/device_status.php?device_id=$deviceId'),
              headers: {'Accept': 'application/json'},
            )
            .timeout(const Duration(seconds: 6));
        lastResponse = res;
        if (res.statusCode != 200) continue;

        var body = res.body;
        if (body.isNotEmpty && body.codeUnitAt(0) == 0xFEFF) {
          body = body.substring(1);
        }
        final decoded = json.decode(body);
        if (decoded is Map && decoded['status'] != null) {
          return decoded['status'].toString().toUpperCase();
        }
      } catch (e) {
        lastError = e;
      }
    }

    final details = lastResponse != null
        ? 'HTTP ${lastResponse.statusCode}: ${lastResponse.body}'
        : (lastError?.toString() ?? 'unknown');
    throw Exception('device_status_failed: $details');
  }

  Future<void> _bootstrap() async {
    await Future.delayed(const Duration(seconds: 2));

    final deviceId = await _getOrCreateDeviceId();

    String? registerError;
    try {
      await _registerDevice(deviceId);
    } catch (e) {
      registerError = e.toString();
    }

    String status;
    String? statusError;
    try {
      status = await _fetchDeviceStatus(deviceId);
    } catch (e) {
      status = 'PENDIENTE';
      statusError = e.toString();
    }

    if (!mounted) return;

    if (status == 'APROBADO') {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MyHomePage(title: 'Puerto Evo – Ventas'),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _DevicePendingPage(
          apiUrls: apiUrls,
          deviceId: deviceId,
          initialRegisterError: registerError,
          initialStatusError: statusError,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFCE4EC),
              const Color(0xFFF8BBD0),
              const Color(0xFFF48FB1),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE91E63).withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/torrez.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        'LOJA DA EMILY',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.2),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Puerto Evo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 50),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DevicePendingPage extends StatefulWidget {
  const _DevicePendingPage({
    required this.apiUrls,
    required this.deviceId,
    this.initialRegisterError,
    this.initialStatusError,
  });

  final List<String> apiUrls;
  final String deviceId;
  final String? initialRegisterError;
  final String? initialStatusError;

  @override
  State<_DevicePendingPage> createState() => _DevicePendingPageState();
}

class _DevicePendingPageState extends State<_DevicePendingPage> {
  bool _isChecking = false;
  Timer? _timer;

  String? _lastRegisterError;
  String? _lastStatusError;
  String? _lastHttpInfo;

  @override
  void initState() {
    super.initState();
    _lastRegisterError = widget.initialRegisterError;
    _lastStatusError = widget.initialStatusError;
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _checkStatus());
    _checkStatus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      http.Response? lastResponse;
      Object? lastError;

      for (final base in widget.apiUrls) {
        try {
          final res = await http
              .get(
                Uri.parse('$base/device_auth/device_status.php?device_id=${widget.deviceId}'),
                headers: {'Accept': 'application/json'},
              )
              .timeout(const Duration(seconds: 6));
          lastResponse = res;
          _lastHttpInfo = '$base → HTTP ${res.statusCode}';

          if (res.statusCode != 200) {
            continue;
          }

          var body = res.body;
          if (body.isNotEmpty && body.codeUnitAt(0) == 0xFEFF) {
            body = body.substring(1);
          }
          final decoded = json.decode(body);
          final status = decoded is Map && decoded['status'] != null
              ? decoded['status'].toString().toUpperCase()
              : 'PENDIENTE';

          if (!mounted) return;

          if (status == 'APROBADO') {
            _timer?.cancel();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const MyHomePage(title: 'Puerto Evo – Ventas'),
              ),
            );
            return;
          }

          _lastStatusError = null;
          return;
        } catch (e) {
          lastError = e;
        }
      }

      if (!mounted) return;
      _lastStatusError = lastResponse != null
          ? 'HTTP ${lastResponse.statusCode}: ${lastResponse.body}'
          : (lastError?.toString() ?? 'unknown');
    } catch (_) {
      // Keep waiting.
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0B1220),
              Color(0xFF111A2E),
              Color(0xFF1B0F2E),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 84,
                  width: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(color: Colors.white.withOpacity(0.14)),
                  ),
                  child: Center(
                    child: _isChecking
                        ? const SizedBox(
                            height: 28,
                            width: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.8,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.lock_rounded, color: Colors.white, size: 34),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Dispositivo pendiente de autorización',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tu dispositivo se registró con este código:\n${widget.deviceId}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                if (_lastHttpInfo != null)
                  Text(
                    _lastHttpInfo!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                if (_lastRegisterError != null || _lastStatusError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    (_lastRegisterError ?? _lastStatusError!).replaceAll('Exception: ', ''),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFFCA5A5).withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Pídele al administrador que lo apruebe en el servidor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isChecking ? null : _checkStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      elevation: 10,
                      shadowColor: const Color(0xFF22C55E).withOpacity(0.35),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text(
                      'REINTENTAR',
                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
