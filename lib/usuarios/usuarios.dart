
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'crear.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  final TextEditingController _searchController = TextEditingController();

  static const String _apiUrl = 'http://192.168.0.224/puerto_evo';

  Future<List<_Usuario>>? _futureUsuarios;

  String _query = '';

  @override
  void initState() {
    super.initState();
    _futureUsuarios = _fetchUsuarios();
  }

  Future<List<_Usuario>> _fetchUsuarios() async {
    final res = await http
        .get(
          Uri.parse('$_apiUrl/usuarios_list.php'),
          headers: {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }

    var body = res.body;
    if (body.isNotEmpty && body.codeUnitAt(0) == 0xFEFF) {
      body = body.substring(1);
    }

    final decoded = json.decode(body);
    if (decoded is! Map || decoded['success'] != true) {
      throw Exception('invalid_response');
    }

    final users = decoded['users'];
    if (users is! List) {
      return [];
    }

    return users.whereType<Map>().map(_Usuario.fromApi).toList();
  }

  List<_Usuario> _filtered(List<_Usuario> usuarios) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return usuarios;
    return usuarios.where((u) {
      return u.nombre.toLowerCase().contains(q) ||
          u.rol.toLowerCase().contains(q) ||
          u.tienda.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Usuarios'),
        centerTitle: true,
        actions: [
          _GlassIconButton(
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () async {
              final created = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CrearUsuarioPage(),
                ),
              );

              if (!mounted) return;
              if (created == true) {
                setState(() => _futureUsuarios = _fetchUsuarios());
              }
            },
          ),
          const SizedBox(width: 12),
        ],
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
              FutureBuilder<List<_Usuario>>(
                future: _futureUsuarios,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                      child: SizedBox(
                        height: 40,
                        width: 40,
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    );
                  }

                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _GlassPanel(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const Icon(Icons.wifi_off_rounded, color: Colors.white),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'No se pudo cargar usuarios: ${snap.error}',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.white.withOpacity(0.85),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _GlassIconButton(
                                    icon: Icons.refresh_rounded,
                                    onPressed: () => setState(() => _futureUsuarios = _fetchUsuarios()),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final usuarios = snap.data ?? const <_Usuario>[];
                  final filtered = _filtered(usuarios);

                  final int total = usuarios.length;
                  final int activos = usuarios.where((u) => u.estado == _UserStatus.activo).length;
                  final int inactivos = total - activos;

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      MediaQuery.of(context).size.width < 600 ? 12 : 16,
                      MediaQuery.of(context).size.width < 600 ? 8 : 10,
                      MediaQuery.of(context).size.width < 600 ? 12 : 16,
                      MediaQuery.of(context).size.width < 600 ? 12 : 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GlassPanel(
                          child: Padding(
                            padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 12 : 16),
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
                                        Icons.groups_rounded,
                                        color: Colors.white,
                                        size: MediaQuery.of(context).size.width < 600 ? 22 : 24,
                                      ),
                                    ),
                                    SizedBox(width: MediaQuery.of(context).size.width < 600 ? 8 : 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Gestión de usuarios',
                                            style: theme.textTheme.titleLarge?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.4,
                                              fontSize: MediaQuery.of(context).size.width < 600 ? 18 : 20,
                                            ),
                                          ),
                                          SizedBox(height: MediaQuery.of(context).size.width < 600 ? 1 : 2),
                                          Text(
                                            'Administración · roles · acceso',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: Colors.white.withOpacity(0.75),
                                              fontWeight: FontWeight.w500,
                                              fontSize: MediaQuery.of(context).size.width < 600 ? 11 : 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _GlassIconButton(
                                      icon: Icons.refresh_rounded,
                                      onPressed: () => setState(() => _futureUsuarios = _fetchUsuarios()),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _GlassSearchField(
                                  controller: _searchController,
                                  hintText: 'Buscar por nombre, rol o tienda…',
                                  onChanged: (v) => setState(() => _query = v),
                                ),
                                const SizedBox(height: 14),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isWide = constraints.maxWidth >= 600;
                                    final cards = <Widget>[
                                      _StatCard(
                                        title: 'Total',
                                        value: '$total',
                                        color: Colors.white,
                                        icon: Icons.person_rounded,
                                      ),
                                      _StatCard(
                                        title: 'Activos',
                                        value: '$activos',
                                        color: const Color(0xFF22C55E),
                                        icon: Icons.verified_rounded,
                                      ),
                                      _StatCard(
                                        title: 'Inactivos',
                                        value: '$inactivos',
                                        color: const Color(0xFFF97316),
                                        icon: Icons.pause_circle_filled_rounded,
                                      ),
                                    ];

                                    if (isWide) {
                                      return Row(
                                        children: [
                                          for (int i = 0; i < cards.length; i++) ...[
                                            Expanded(child: cards[i]),
                                            if (i != cards.length - 1) const SizedBox(width: 10),
                                          ]
                                        ],
                                      );
                                    }

                                    return Column(
                                      children: [
                                        for (int i = 0; i < cards.length; i++) ...[
                                          cards[i],
                                          if (i != cards.length - 1) const SizedBox(height: 10),
                                        ]
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Text(
                              'Lista',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${filtered.length} resultados',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white.withOpacity(0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: filtered.isEmpty
                              ? _GlassPanel(
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.search_off_rounded, color: Colors.white),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'No se encontraron usuarios con ese filtro.',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: Colors.white.withOpacity(0.85),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final u = filtered[index];
                                    return _UserCard(usuario: u);
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
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
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(22),
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

class _GlassSearchField extends StatelessWidget {
  const _GlassSearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const Icon(Icons.search_rounded, color: Colors.white),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return _GlassPanel(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 14),
        child: Row(
          children: [
            Container(
              height: isMobile ? 36 : 40,
              width: isMobile ? 36 : 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.22),
                    color.withOpacity(0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: color.withOpacity(0.28)),
              ),
              child: Icon(icon, color: color, size: isMobile ? 18 : 20),
            ),
            SizedBox(width: isMobile ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w700,
                      fontSize: isMobile ? 11 : 12,
                    ),
                  ),
                  SizedBox(height: isMobile ? 1 : 2),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: isMobile ? 18 : 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.usuario});

  final _Usuario usuario;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isActive = usuario.estado == _UserStatus.activo;
    final statusColor = isActive ? const Color(0xFF22C55E) : const Color(0xFFF97316);

    return _GlassPanel(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 14),
        child: Row(
          children: [
            Container(
              height: isMobile ? 40 : 46,
              width: isMobile ? 40 : 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE91E63).withOpacity(0.85),
                    const Color(0xFF7C3AED).withOpacity(0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  usuario.initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
              ),
            ),
            SizedBox(width: isMobile ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          usuario.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                            fontSize: isMobile ? 14 : 16,
                          ),
                        ),
                      ),
                      SizedBox(width: isMobile ? 6 : 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 10,
                          vertical: isMobile ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: statusColor.withOpacity(0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isActive ? Icons.circle : Icons.circle_outlined,
                              size: isMobile ? 8 : 10,
                              color: statusColor,
                            ),
                            SizedBox(width: isMobile ? 4 : 6),
                            Text(
                              isActive ? 'Activo' : 'Inactivo',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w800,
                                fontSize: isMobile ? 10 : 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 4 : 6),
                  Row(
                    children: [
                      Icon(
                        Icons.badge_rounded,
                        size: isMobile ? 14 : 16,
                        color: Colors.white.withOpacity(0.75),
                      ),
                      SizedBox(width: isMobile ? 4 : 6),
                      Expanded(
                        child: Text(
                          usuario.rol,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.85),
                            fontWeight: FontWeight.w700,
                            fontSize: isMobile ? 12 : 14,
                          ),
                        ),
                      ),
                      SizedBox(width: isMobile ? 8 : 12),
                      Icon(
                        Icons.store_rounded,
                        size: isMobile ? 14 : 16,
                        color: Colors.white.withOpacity(0.75),
                      ),
                      SizedBox(width: isMobile ? 4 : 6),
                      Flexible(
                        child: Text(
                          usuario.tienda,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.75),
                            fontWeight: FontWeight.w600,
                            fontSize: isMobile ? 11 : 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: isMobile ? 8 : 10),
            _GlassIconButton(
              icon: Icons.edit_rounded,
              onPressed: () {},
            ),
            if (!isMobile) SizedBox(width: 10),
            if (!isMobile)
              _GlassIconButton(
                icon: Icons.more_horiz_rounded,
                onPressed: () {},
              ),
          ],
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

enum _UserStatus { activo, inactivo }

class _Usuario {
  const _Usuario({
    required this.nombre,
    required this.rol,
    required this.tienda,
    required this.estado,
  });

  final String nombre;
  final String rol;
  final String tienda;
  final _UserStatus estado;

  factory _Usuario.fromApi(Map raw) {
    final nombre = (raw['nombre'] ?? '').toString();
    final rol = (raw['rol'] ?? '').toString();
    final tienda = (raw['tienda'] ?? '').toString();
    final estadoStr = (raw['estado'] ?? '').toString().toUpperCase();
    final estado = estadoStr == 'ACTIVO' ? _UserStatus.activo : _UserStatus.inactivo;
    return _Usuario(
      nombre: nombre.isEmpty ? 'Sin nombre' : nombre,
      rol: rol.isEmpty ? 'USUARIO' : rol,
      tienda: tienda.isEmpty ? '-' : tienda,
      estado: estado,
    );
  }

  String get initials {
    final parts = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    final first = parts.first.characters.isNotEmpty ? parts.first.characters.first : 'U';
    final second = parts.length > 1 && parts[1].characters.isNotEmpty ? parts[1].characters.first : '';
    return (first + second).toUpperCase();
  }
}
