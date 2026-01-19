import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

enum _ArticuloFilter { all, low, critical }

typedef _Tag = ({String label, Color color, IconData icon});

class _ArticuloItem {
  const _ArticuloItem({
    required this.name,
    required this.barcode,
    required this.price,
    required this.stock,
    required this.tags,
    this.imageUrl,
  });

  final String name;
  final String barcode;
  final double price;
  final int stock;
  final List<_Tag> tags;
  final String? imageUrl;
}

class ArticulosPage extends StatefulWidget {
  const ArticulosPage({super.key});

  @override
  State<ArticulosPage> createState() => _ArticulosPageState();
}

class _ArticulosPageState extends State<ArticulosPage> {
  final TextEditingController _searchController = TextEditingController();

  _ArticuloFilter _filter = _ArticuloFilter.all;
  String _query = '';
  bool _isLoading = true;
  bool _isCreating = false;

  final String _apiUrl = 'http://192.168.0.14/puerto_evo/puerto_evo';

  int _tiendaActual = 1;

  List<_ArticuloItem> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse('$_apiUrl/get_inventario.php?tienda=$_tiendaActual');
      final resp = await http.get(uri);
      
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['success'] == true) {
          final List products = data['productos'];
          final List<_ArticuloItem> loaded = products.map((e) {
            // Parse tags based on logic or random for now as PHP doesn't return tags
            // For demo, we keep simple tags
            final stock = int.tryParse(e['stock'].toString()) ?? 0;
            return _ArticuloItem(
              name: e['nombre_producto'],
              barcode: e['codigo_barras'],
              price: double.tryParse(e['precio'].toString()) ?? 0.0,
              stock: stock,
              imageUrl: e['imagen_url'],
              tags: stock <= 5 
                  ? [(label: 'Crítico', color: const Color(0xFFDC2626), icon: Icons.priority_high_rounded)]
                  : [(label: 'General', color: const Color(0xFF2563EB), icon: Icons.inventory_2_rounded)],
            );
          }).toList();

          if (mounted) setState(() => _items = loaded);
        }
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_ArticuloItem> get _filteredItems {
    final normalizedQuery = _query.trim().toLowerCase();

    Iterable<_ArticuloItem> list = _items;

    if (normalizedQuery.isNotEmpty) {
      list = list.where(
        (e) =>
            e.name.toLowerCase().contains(normalizedQuery) ||
            e.barcode.contains(normalizedQuery),
      );
    }

    switch (_filter) {
      case _ArticuloFilter.low:
        list = list.where((e) => e.stock <= 10 && e.stock > 5);
        break;
      case _ArticuloFilter.critical:
        list = list.where((e) => e.stock <= 5);
        break;
      case _ArticuloFilter.all:
        break;
    }

    return list.toList();
  }

  int get _countLow => _items.where((e) => e.stock <= 10 && e.stock > 5).length;
  int get _countCritical => _items.where((e) => e.stock <= 5).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _isLoading
              ? const Center(
                  key: ValueKey('loading'),
                  child: SizedBox(
                    height: 42,
                    width: 42,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                )
              : SingleChildScrollView(
                  key: const ValueKey('content'),
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeroHeader(
                        title: 'Artículos',
                        subtitle: 'Catálogo y control rápido',
                        accent: const Color(0xFF14B8A6),
                        icon: Icons.list_alt_rounded,
                      ),
                      const SizedBox(height: 14),
                      _QuickStatsRow(
                        total: _items.length,
                        low: _countLow,
                        critical: _countCritical,
                      ),
                      const SizedBox(height: 14),
                      _SearchBar(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() => _query = value);
                        },
                        onClear: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                      const SizedBox(height: 12),
                      _Filters(
                        value: _filter,
                        onChanged: (value) {
                          setState(() => _filter = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Resultados',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _filteredItems.isEmpty
                            ? _EmptyState(
                                key: const ValueKey('empty'),
                                query: _query,
                              )
                            : Column(
                                key: const ValueKey('list'),
                                children: List.generate(
                                  _filteredItems.length,
                                  (index) {
                                    final item = _filteredItems[index];
                                    return _AnimatedAppear(
                                      index: index,
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: _ArticuloCard(item: item),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            onPressed: _isCreating ? null : _openCreateDialog,
            child: _isCreating
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Icon(Icons.add_rounded, size: 30),
          ),
        ),
      ],
    );
  }

  Future<void> _openCreateDialog() async {
    final codigoController = TextEditingController();
    final nombreController = TextEditingController();
    final costoTotalController = TextEditingController();
    final precioVentaController = TextEditingController();
    final stockController = TextEditingController();

    String? imagePath;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> pickImage() async {
              final picked = await FilePicker.platform.pickFiles(
                type: FileType.image,
                allowMultiple: false,
              );
              if (picked == null || picked.files.isEmpty) return;
              final path = picked.files.single.path;
              if (path == null) return;
              setLocalState(() => imagePath = path);
            }

            void clearImage() {
              setLocalState(() => imagePath = null);
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFF0FDFA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF14B8A6).withOpacity(0.18),
                      blurRadius: 40,
                      offset: const Offset(0, 18),
                    ),
                  ],
                  border: Border.all(color: Colors.white.withOpacity(0.85), width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF14B8A6).withOpacity(0.22),
                                  const Color(0xFF0EA5E9).withOpacity(0.10),
                                ],
                              ),
                            ),
                            child: const Icon(Icons.add_rounded, color: Color(0xFF0F766E)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nuevo artículo',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.6,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Crea un producto y opcionalmente sube una imagen.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _DialogField(
                        controller: codigoController,
                        label: 'Código de barras',
                        hint: 'Ej: 7758...',
                        icon: Icons.qr_code_2_rounded,
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 10),
                      _DialogField(
                        controller: nombreController,
                        label: 'Nombre del producto',
                        hint: 'Ej: Agua 2L',
                        icon: Icons.shopping_bag_rounded,
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _DialogField(
                              controller: costoTotalController,
                              label: 'Costo total',
                              hint: '0.00',
                              icon: Icons.payments_rounded,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DialogField(
                              controller: precioVentaController,
                              label: 'Precio venta unitario',
                              hint: '0.00',
                              icon: Icons.price_check_rounded,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _DialogField(
                              controller: stockController,
                              label: 'Stock',
                              hint: '1',
                              icon: Icons.inventory_2_rounded,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TiendaPicker(
                              value: _tiendaActual,
                              onChanged: (v) {
                                setState(() => _tiendaActual = v);
                                setLocalState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withOpacity(0.75),
                          border: Border.all(color: Colors.black.withOpacity(0.06)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 36,
                              width: 36,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.black.withOpacity(0.04),
                              ),
                              child: const Icon(Icons.image_rounded, color: Colors.black54),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                imagePath == null ? 'Imagen (opcional)' : imagePath!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 10),
                            TextButton.icon(
                              onPressed: pickImage,
                              icon: const Icon(Icons.upload_rounded),
                              label: const Text('Elegir'),
                            ),
                            if (imagePath != null)
                              IconButton(
                                tooltip: 'Quitar imagen',
                                onPressed: clearImage,
                                icon: const Icon(Icons.close_rounded),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: () async {
                                final ok = await _createArticulo(
                                  codigo: codigoController.text,
                                  nombre: nombreController.text,
                                  costoTotal: costoTotalController.text,
                                  precioVentaUnitario: precioVentaController.text,
                                  stock: stockController.text,
                                  tienda: _tiendaActual,
                                  imagePath: imagePath,
                                );
                                if (!context.mounted) return;
                                Navigator.of(context).pop(ok);
                              },
                              icon: const Icon(Icons.save_rounded),
                              label: const Text('Guardar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    codigoController.dispose();
    nombreController.dispose();
    costoTotalController.dispose();
    precioVentaController.dispose();
    stockController.dispose();

    if (result == true) {
      if (!mounted) return;
      _fetchData(); // Refresh list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Artículo creado correctamente'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  Future<bool> _createArticulo({
    required String codigo,
    required String nombre,
    required String costoTotal,
    required String precioVentaUnitario,
    required String stock,
    required int tienda,
    required String? imagePath,
  }) async {
    final codigoTrim = codigo.trim();
    final nombreTrim = nombre.trim();
    final stockInt = int.tryParse(stock.trim()) ?? 0;
    final costo = double.tryParse(costoTotal.trim().replaceAll(',', '.')) ?? 0;
    final precio = double.tryParse(precioVentaUnitario.trim().replaceAll(',', '.')) ?? 0;

    if (codigoTrim.isEmpty || nombreTrim.isEmpty || stockInt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Completa código, nombre y stock (stock > 0).'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return false;
    }

    setState(() => _isCreating = true);
    try {
      final uri = Uri.parse('$_apiUrl/agregar_producto.php');
      final req = http.MultipartRequest('POST', uri);
      req.fields['codigo_barras'] = codigoTrim;
      req.fields['nombre_producto'] = nombreTrim;
      req.fields['costo_total'] = costo.toStringAsFixed(2);
      req.fields['precio_venta_unitario'] = precio.toStringAsFixed(2);
      req.fields['stock'] = stockInt.toString();
      req.fields['tienda'] = tienda.toString();

      if (imagePath != null && imagePath.trim().isNotEmpty) {
        final file = File(imagePath);
        if (await file.exists()) {
          req.files.add(await http.MultipartFile.fromPath('imagen', file.path));
        }
      }

      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode != 200) {
        throw Exception('HTTP ${streamed.statusCode}: $body');
      }

      final data = json.decode(body);
      if (data is Map && data['success'] == true) {
        return true;
      }

      final err = (data is Map ? data['error'] : null) ?? 'Error desconocido';
      throw Exception(err.toString());
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return false;
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }
}



class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800),
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }
}

class _TiendaPicker extends StatelessWidget {
  const _TiendaPicker({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 1, child: Text('Puerto Centro')),
            DropdownMenuItem(value: 2, child: Text('Puerto Norte')),
          ],
          onChanged: (v) {
            if (v == null) return;
            onChanged(v);
          },
        ),
      ),
    );
  }
}

class _AnimatedAppear extends StatelessWidget {
  const _AnimatedAppear({
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 260 + (index * 55)),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: child,
          ),
        );
      },
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            accent.withOpacity(0.95),
            const Color(0xFF0EA5E9).withOpacity(0.65),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.18),
              border: Border.all(color: Colors.white.withOpacity(0.28)),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.92),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.24)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({
    required this.total,
    required this.low,
    required this.critical,
  });

  final int total;
  final int low;
  final int critical;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatPill(
            title: 'Total',
            value: '$total',
            icon: Icons.inventory_2_rounded,
            color: const Color(0xFF0EA5E9),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatPill(
            title: 'Bajo',
            value: '$low',
            icon: Icons.warning_rounded,
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatPill(
            title: 'Crítico',
            value: '$critical',
            icon: Icons.error_rounded,
            color: const Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.7), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [color.withOpacity(0.22), color.withOpacity(0.10)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          hintText: 'Buscar por nombre o código…',
          hintStyle: TextStyle(color: Colors.black.withOpacity(0.35), fontWeight: FontWeight.w600),
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF14B8A6).withOpacity(0.20),
                  const Color(0xFF0EA5E9).withOpacity(0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.search_rounded, color: Color(0xFF0F766E)),
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.trim().isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Limpiar',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.value,
    required this.onChanged,
  });

  final _ArticuloFilter value;
  final ValueChanged<_ArticuloFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _FilterChip(
          label: 'Todos',
          icon: Icons.grid_view_rounded,
          selected: value == _ArticuloFilter.all,
          onTap: () => onChanged(_ArticuloFilter.all),
          color: const Color(0xFF0EA5E9),
        ),
        _FilterChip(
          label: 'Bajo stock',
          icon: Icons.warning_rounded,
          selected: value == _ArticuloFilter.low,
          onTap: () => onChanged(_ArticuloFilter.low),
          color: const Color(0xFFF59E0B),
        ),
        _FilterChip(
          label: 'Crítico',
          icon: Icons.error_rounded,
          selected: value == _ArticuloFilter.critical,
          onTap: () => onChanged(_ArticuloFilter.critical),
          color: const Color(0xFFEF4444),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? color.withOpacity(0.16) : Colors.white.withOpacity(0.65),
          border: Border.all(
            color: selected ? color.withOpacity(0.35) : Colors.white.withOpacity(0.8),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: selected ? color.withOpacity(0.12) : Colors.black.withOpacity(0.03),
              blurRadius: selected ? 16 : 10,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? color : Colors.black54),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
                color: selected ? color : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticuloCard extends StatelessWidget {
  const _ArticuloCard({required this.item});

  final _ArticuloItem item;

  Color get _statusColor {
    if (item.stock <= 5) return const Color(0xFFEF4444);
    if (item.stock <= 10) return const Color(0xFFF59E0B);
    return const Color(0xFF22C55E);
  }

  String get _statusLabel {
    if (item.stock <= 5) return 'Crítico';
    if (item.stock <= 10) return 'Bajo';
    return 'OK';
  }

  IconData get _statusIcon {
    if (item.stock <= 5) return Icons.priority_high_rounded;
    if (item.stock <= 10) return Icons.warning_rounded;
    return Icons.check_circle_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        border: Border.all(color: Colors.black.withOpacity(0.06), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side: Information
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: Colors.black87,
                    height: 1.2,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 15, color: Colors.black45),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.barcode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MiniInfo(
                        icon: Icons.price_check_rounded,
                        label: 'Precio',
                        value: 'Bs ${item.price.toStringAsFixed(2)}',
                        color: const Color(0xFF0EA5E9),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniInfo(
                        icon: Icons.inventory_2_rounded,
                        label: 'Stock',
                        value: '${item.stock}',
                        color: _statusColor,
                      ),
                    ),
                  ],
                ),
                if (item.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: item.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: tag.color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: tag.color.withOpacity(0.15)),
                        ),
                        child: Text(
                          tag.label,
                          style: TextStyle(
                            color: tag.color,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Right Side: Image and Status
          Column(
            children: [
              Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.black.withOpacity(0.04)),
                ),
                child: item.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: Colors.black26),
                        ),
                      )
                    : const Icon(Icons.image_not_supported_rounded, color: Colors.black12, size: 32),
              ),
              const SizedBox(height: 10),
              _StatusBadge(
                color: _statusColor,
                label: _statusLabel,
                icon: _statusIcon,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.color,
    required this.label,
    required this.icon,
  });

  final Color color;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.24), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withOpacity(0.03),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required super.key,
    required this.query,
  });

  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.72),
        border: Border.all(color: Colors.white.withOpacity(0.86), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0EA5E9).withOpacity(0.18),
                  const Color(0xFF14B8A6).withOpacity(0.10),
                ],
              ),
            ),
            child: const Icon(Icons.search_off_rounded, color: Color(0xFF0EA5E9)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sin resultados',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  query.trim().isEmpty
                      ? 'Prueba buscando por nombre o código.'
                      : 'No encontré coincidencias para "$query".',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
