
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CrearUsuarioPage extends StatefulWidget {
  const CrearUsuarioPage({super.key});

  @override
  State<CrearUsuarioPage> createState() => _CrearUsuarioPageState();
}

class _CrearUsuarioPageState extends State<CrearUsuarioPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _claveController = TextEditingController();

  bool _mostrarClave = false;
  bool _isLoading = false;

  String _rol = 'USUARIO';
  int _tienda = 1;
  bool _activo = true;

  final String apiUrl = 'http://192.168.0.224/puerto_evo';

  String _normalizeUsuario(String input) {
    var v = input.trim();
    v = v.replaceAll('@', '');
    v = v.replaceAll(' ', '');
    return v;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _usuarioController.dispose();
    _claveController.dispose();
    super.dispose();
  }

  Future<void> _crearUsuario() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() => _isLoading = true);

    try {
      final payload = {
        'nombre': _nombreController.text.trim(),
        'usuario': _normalizeUsuario(_usuarioController.text),
        'clave': _claveController.text,
        'rol': _rol,
        'tienda': _tienda,
        'estado': _activo ? 'ACTIVO' : 'INACTIVO',
      };

      final response = await http.post(
        Uri.parse('$apiUrl/crear_usuario.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final ok = decoded is Map && decoded['success'] == true;

        if (ok) {
          await showGeneralDialog(
            context: context,
            barrierDismissible: true,
            barrierLabel: 'ok',
            pageBuilder: (_, __, ___) => const SizedBox.shrink(),
            transitionBuilder: (context, anim1, anim2, child) {
              return ScaleTransition(
                scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
                child: AlertDialog(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  contentPadding: EdgeInsets.zero,
                  content: _GlassPanel(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF22C55E).withOpacity(0.95),
                                const Color(0xFF16A34A).withOpacity(0.75),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(Icons.check_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Usuario creado correctamente',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );

          if (!mounted) return;
          Navigator.of(context).pop(true);
        } else {
          final msg = decoded is Map
              ? (decoded['message'] ?? decoded['error'] ?? 'No se pudo crear el usuario')
              : 'No se pudo crear el usuario';
          _showSnack(msg.toString(), const Color(0xFFEF4444));
        }
      } else {
        _showSnack('Error HTTP: ${response.statusCode}', const Color(0xFFEF4444));
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error de conexión: $e', const Color(0xFFEF4444));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Crear usuario'),
        centerTitle: true,
      ),
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
          child: Stack(
            children: [
              Positioned(
                top: -80,
                left: -60,
                child: _GlowOrb(color: const Color(0xFFE91E63).withOpacity(0.45), size: 220),
              ),
              Positioned(
                top: 140,
                right: -80,
                child: _GlowOrb(color: const Color(0xFF7C3AED).withOpacity(0.35), size: 260),
              ),
              Positioned(
                bottom: -100,
                left: -80,
                child: _GlowOrb(color: const Color(0xFF22C55E).withOpacity(0.25), size: 260),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  MediaQuery.of(context).size.width < 600 ? 12 : 16,
                  MediaQuery.of(context).size.width < 600 ? 8 : 10,
                  MediaQuery.of(context).size.width < 600 ? 12 : 16,
                  MediaQuery.of(context).size.width < 600 ? 12 : 16,
                ),
                child: Column(
                  children: [
                    _GlassPanel(
                      borderRadius: 22,
                      padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 12 : 16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  height: MediaQuery.of(context).size.width < 600 ? 40 : 46,
                                  width: MediaQuery.of(context).size.width < 600 ? 40 : 46,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        colorScheme.primary.withOpacity(0.95),
                                        const Color(0xFF7C3AED).withOpacity(0.9),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.person_add_alt_1_rounded,
                                    color: Colors.white,
                                    size: MediaQuery.of(context).size.width < 600 ? 22 : 24,
                                  ),
                                ),
                                SizedBox(width: MediaQuery.of(context).size.width < 600 ? 8 : 12),
                                Expanded(
                                  child: Text(
                                    'Nuevo usuario',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: MediaQuery.of(context).size.width < 600 ? 16 : 18,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                ),
                                _GlassIconButton(
                                  icon: Icons.auto_awesome_rounded,
                                  onPressed: () {},
                                ),
                              ],
                            ),
                            SizedBox(height: MediaQuery.of(context).size.width < 600 ? 12 : 14),
                            _GlassTextField(
                              controller: _nombreController,
                              label: 'Nombre completo',
                              icon: Icons.badge_rounded,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Ingresa el nombre';
                                if (v.trim().length < 3) return 'Nombre muy corto';
                                return null;
                              },
                            ),
                            SizedBox(height: MediaQuery.of(context).size.width < 600 ? 10 : 12),
                            _GlassTextField(
                              controller: _usuarioController,
                              label: 'Usuario',
                              icon: Icons.alternate_email_rounded,
                              onChanged: (v) {
                                final normalized = _normalizeUsuario(v);
                                if (normalized != v) {
                                  _usuarioController.value = TextEditingValue(
                                    text: normalized,
                                    selection: TextSelection.collapsed(offset: normalized.length),
                                  );
                                }
                              },
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Ingresa un nombre de usuario (ej: jperez)';
                                final normalized = _normalizeUsuario(v);
                                if (normalized.length < 3) return 'El usuario debe tener al menos 3 caracteres';
                                final ok = RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(normalized);
                                if (!ok) return 'Solo se permiten letras, números, punto, guión y guión bajo';
                                return null;
                              },
                            ),
                            SizedBox(height: MediaQuery.of(context).size.width < 600 ? 10 : 12),
                            _GlassTextField(
                              controller: _claveController,
                              label: 'Contraseña',
                              icon: Icons.lock_rounded,
                              obscureText: !_mostrarClave,
                              suffix: IconButton(
                                onPressed: () => setState(() => _mostrarClave = !_mostrarClave),
                                icon: Icon(
                                  _mostrarClave ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                                if (v.length < 4) return 'Mínimo 4 caracteres';
                                return null;
                              },
                            ),
                            SizedBox(height: MediaQuery.of(context).size.width < 600 ? 10 : 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isMobile = MediaQuery.of(context).size.width < 600;
                                
                                if (isMobile) {
                                  return Column(
                                    children: [
                                      _GlassDropdown<String>(
                                        label: 'Rol',
                                        icon: Icons.security_rounded,
                                        value: _rol,
                                        items: const ['ADMIN', 'USUARIO'],
                                        onChanged: (v) {
                                          if (v == null) return;
                                          setState(() => _rol = v);
                                        },
                                      ),
                                      SizedBox(height: 10),
                                      _GlassDropdown<int>(
                                        label: 'Tienda',
                                        icon: Icons.store_rounded,
                                        value: _tienda,
                                        items: const [1, 2],
                                        onChanged: (v) {
                                          if (v == null) return;
                                          setState(() => _tienda = v);
                                        },
                                      ),
                                    ],
                                  );
                                } else {
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: _GlassDropdown<String>(
                                          label: 'Rol',
                                          icon: Icons.security_rounded,
                                          value: _rol,
                                          items: const ['ADMIN', 'USUARIO'],
                                          onChanged: (v) {
                                            if (v == null) return;
                                            setState(() => _rol = v);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _GlassDropdown<int>(
                                          label: 'Tienda',
                                          icon: Icons.store_rounded,
                                          value: _tienda,
                                          items: const [1, 2],
                                          onChanged: (v) {
                                            if (v == null) return;
                                            setState(() => _tienda = v);
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                            SizedBox(height: MediaQuery.of(context).size.width < 600 ? 10 : 12),
                            _GlassPanel(
                              borderRadius: 18,
                              padding: EdgeInsets.symmetric(
                                horizontal: MediaQuery.of(context).size.width < 600 ? 12 : 14,
                                vertical: MediaQuery.of(context).size.width < 600 ? 8 : 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.power_settings_new_rounded,
                                    color: Colors.white.withOpacity(0.85),
                                    size: MediaQuery.of(context).size.width < 600 ? 16 : 18,
                                  ),
                                  SizedBox(width: MediaQuery.of(context).size.width < 600 ? 8 : 10),
                                  Expanded(
                                    child: Text(
                                      _activo ? 'Usuario activo' : 'Usuario inactivo',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.w700,
                                        fontSize: MediaQuery.of(context).size.width < 600 ? 13 : 14,
                                      ),
                                    ),
                                  ),
                                  Switch.adaptive(
                                    value: _activo,
                                    activeColor: const Color(0xFF22C55E),
                                    onChanged: (v) => setState(() => _activo = v),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: MediaQuery.of(context).size.width < 600 ? 12 : 14),
                            SizedBox(
                              width: double.infinity,
                              height: MediaQuery.of(context).size.width < 600 ? 48 : 54,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _crearUsuario,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF22C55E),
                                  foregroundColor: Colors.white,
                                  elevation: 10,
                                  shadowColor: const Color(0xFF22C55E).withOpacity(0.4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                ),
                                icon: _isLoading
                                    ? SizedBox(
                                        height: MediaQuery.of(context).size.width < 600 ? 16 : 18,
                                        width: MediaQuery.of(context).size.width < 600 ? 16 : 18,
                                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                                      )
                                    : Icon(
                                        Icons.save_rounded,
                                        size: MediaQuery.of(context).size.width < 600 ? 20 : 24,
                                      ),
                                label: Text(
                                  _isLoading ? 'CREANDO...' : 'CREAR USUARIO',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                    fontSize: MediaQuery.of(context).size.width < 600 ? 13 : 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Endpoint: $apiUrl/crear_usuario.php',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: Colors.white.withOpacity(0.10),
          child: InkWell(
            onTap: onPressed,
            child: Container(
              height: 42,
              width: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.18)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    required this.borderRadius,
    this.padding,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    this.obscureText = false,
    this.onChanged,
    this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?) validator;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: TextFormField(
          controller: controller,
          validator: validator,
          obscureText: obscureText,
          onChanged: onChanged,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontWeight: FontWeight.w700,
            ),
            prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.85)),
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.white.withOpacity(0.10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.16)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.16)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.7), width: 1.6),
            ),
            errorStyle: const TextStyle(height: 0.8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ),
    );
  }
}

class _GlassDropdown<T> extends StatelessWidget {
  const _GlassDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DropdownButtonFormField<T>(
          value: value,
          items: items
              .map(
                (v) => DropdownMenuItem<T>(
                  value: v,
                  child: Text(
                    v.toString(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          dropdownColor: const Color(0xFF111A2E),
          style: TextStyle(
            color: Colors.white.withOpacity(0.92),
            fontWeight: FontWeight.w800,
          ),
          iconEnabledColor: Colors.white.withOpacity(0.85),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontWeight: FontWeight.w700,
            ),
            prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.85)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.16)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.16)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.7), width: 1.6),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 120,
              spreadRadius: 40,
            ),
          ],
        ),
      ),
    );
  }
}
