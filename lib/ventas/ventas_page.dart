import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';

class VentasPage extends StatefulWidget {
  const VentasPage({super.key});

  @override
  State<VentasPage> createState() => _VentasPageState();
}

class _VentasPageState extends State<VentasPage> with SingleTickerProviderStateMixin {
  final List<_CartItem> _cart = [];
  bool _isLoading = false;
  
  // URL API 
  final String apiUrl = 'http://192.168.0.224/puerto_evo';
  int _tiendaActual = 1; // Default: Puerto Centro

  double get _totalVenta => _cart.fold(0, (sum, item) => sum + item.subtotal);

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    _scaleAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _cambiarTienda(int nuevaTienda) {
    if (_tiendaActual == nuevaTienda) return;
    
    if (_cart.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.9),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('¿Cambiar de Tienda?'),
          content: const Text(
            'Si cambias de tienda, se vaciará el carrito actual.',
            style: TextStyle(color: Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _tiendaActual = nuevaTienda;
                  _cart.clear();
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        _tiendaActual = nuevaTienda;
      });
    }
  }

  void _addToCart(Map<String, dynamic> product, int currentStock) {
    HapticFeedback.lightImpact();
    try {
      final rawId = product['id_producto'] ?? product['id'];
      if (rawId == null) throw Exception('ID de producto no encontrado');
      
      final productId = int.parse(rawId.toString());
      final rawPrice = product['precio'] ?? product['precio_venta'] ?? '0';
      final productPrice = double.parse(rawPrice.toString());

      setState(() {
        final existingIndex = _cart.indexWhere((item) => item.id == productId);
        
        if (existingIndex >= 0) {
          if (_cart[existingIndex].quantity < currentStock) {
            _cart[existingIndex].quantity++;
            _showSnack('Cantidad actualizada', Colors.green);
          } else {
            _showSnack('Stock máximo alcanzado', Colors.orange);
          }
        } else {
          _cart.add(_CartItem(
            id: productId,
            name: product['nombre_producto'] ?? 'Producto sin nombre',
            price: productPrice,
            quantity: 1,
            maxStock: currentStock,
          ));
          _showSnack('Agregado al carrito', Colors.green);
        }
      });
    } catch (e) {
      _showSnack('Error al agregar: $e', Colors.red);
    }
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

  Future<void> _processSale() async {
    if (_cart.isEmpty) return;

    setState(() => _isLoading = true);
    
    try {
      final saleData = {
        'tienda_id': _tiendaActual,
        'total': _totalVenta,
        'productos': _cart.map((item) => {
          'id': item.id,
          'cantidad': item.quantity,
          'precio': item.price,
          'subtotal': item.subtotal
        }).toList(),
      };

      final response = await http.post(
        Uri.parse('$apiUrl/registrar_venta.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(saleData),
      );

      if (response.statusCode == 200) {
         final result = json.decode(response.body);
         if (result['success'] == true) {
           _showSuccessDialog(result['ticket'].toString(), _totalVenta);
           setState(() {
             _cart.clear();
           });
         } else {
           _showSnack('Error: ${result['error'] ?? result['message']}', Colors.red);
         }
      } else {
        _showSnack('Error HTTP: ${response.statusCode}', Colors.red);
      }
    } catch (e) {
      _showSnack('Error de conexión: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String ticket, double total) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Success',
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            content: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 30, spreadRadius: 5)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 48),
                  ),
                  const SizedBox(height: 24),
                  const Text('¡Venta Exitosa!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Ticket #$ticket', style: const TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 24),
                  Text('Bs ${total.toStringAsFixed(2)}', 
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(context); // Close page
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('TERMINAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
            stops: [0.3, 0.9],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- CUSTOM HEADER ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _GlassBox(
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const Text(
                      'Nueva Venta',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF14532D),
                        letterSpacing: -0.5,
                      ),
                    ),
                    _GlassBox(
                      child: IconButton(
                        icon: const Icon(Icons.more_horiz_rounded),
                        onPressed: () {}, // Future options
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // --- STORE SELECTOR CAPSULE ---
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _StoreToggle(
                        title: 'Puerto Centro',
                        isActive: _tiendaActual == 1,
                        onTap: () => _cambiarTienda(1),
                      ),
                    ),
                    Expanded(
                      child: _StoreToggle(
                        title: 'Puerto Norte',
                        isActive: _tiendaActual == 2,
                        onTap: () => _cambiarTienda(2),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- TOTAL DISPLAY ---
              ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  children: [
                    Text(
                      'Total a Pagar',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bs ${_totalVenta.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF16A34A),
                        height: 1.0,
                        letterSpacing: -2,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- LISTA DE PRODUCTOS ---
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 30, offset: Offset(0, -10)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                    child: _cart.isEmpty
                      ? _EmptyCartState(
                          onAdd: () => _showManualSelectionDialog(context),
                        )
                      : Stack(
                          children: [
                            ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 30, 20, 100),
                              physics: const BouncingScrollPhysics(),
                              itemCount: _cart.length,
                              itemBuilder: (context, index) {
                                return _CartItemRow(
                                  item: _cart[index],
                                  onAdd: () => setState(() {
                                    if (_cart[index].quantity < _cart[index].maxStock) {
                                      _cart[index].quantity++;
                                      HapticFeedback.selectionClick();
                                    }
                                  }),
                                  onRemove: () => setState(() {
                                    if (_cart[index].quantity > 1) {
                                      _cart[index].quantity--;
                                      HapticFeedback.selectionClick();
                                    } else {
                                      _removeFromCart(index);
                                    }
                                  }),
                                  onDelete: () => _removeFromCart(index),
                                );
                              },
                            ),
                            // Floating Button
                            Positioned(
                              bottom: 24,
                              right: 24,
                              child: FloatingActionButton.extended(
                                onPressed: () => _showManualSelectionDialog(context),
                                label: const Text('AGREGAR'),
                                icon: const Icon(Icons.add),
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                elevation: 5,
                              ),
                            ),
                          ],
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // --- BOTTOM SHEET FOR CHECKOUT ---
      bottomSheet: _cart.isEmpty
          ? null
          : Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _processSale,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      elevation: 10,
                      shadowColor: const Color(0xFF16A34A).withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('CONFIRMAR VENTA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                              SizedBox(width: 10),
                              Icon(Icons.arrow_forward_rounded)
                            ],
                          ),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _showManualSelectionDialog(BuildContext context) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      pageBuilder: (context, a1, a2) {
        return _ProductSelectionDialog(
          apiUrl: apiUrl,
          tiendaId: _tiendaActual,
          onProductSelected: (p, s) => _addToCart(p, s),
        );
      },
      transitionBuilder: (context, a1, a2, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: a1, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }
}

// ---------------- CUSTOM COMPONENTS ----------------

class _GlassBox extends StatelessWidget {
  final Widget child;
  const _GlassBox({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
      ),
      child: child,
    );
  }
}

class _StoreToggle extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _StoreToggle({required this.title, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF16A34A) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isActive 
             ? [BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))] 
             : [],
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final _CartItem item;
  final VoidCallback onAdd, onRemove, onDelete;

  const _CartItemRow({required this.item, required this.onAdd, required this.onRemove, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_forever_rounded, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              height: 48, width: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9), 
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Icon(Icons.shopping_bag_outlined, color: Color(0xFF64748B), size: 24)),
            ),
            const SizedBox(width: 16),
            
            // Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, 
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1E293B))),
                  const SizedBox(height: 4),
                  Text('Bs ${item.price.toStringAsFixed(2)}', 
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF16A34A))),
                ],
              ),
            ),
            
            // Push Selector to Right
            // Quantity Capsule
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QtyButton(
                    icon: Icons.remove, 
                    onTap: onRemove,
                    color: const Color(0xFF94A3B8), // Grey for minus
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 24),
                    alignment: Alignment.center,
                    child: Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.w900, 
                        color: Color(0xFF0F172A)
                      ),
                    ),
                  ),
                  _QtyButton(
                    icon: Icons.add, 
                    onTap: onAdd,
                    color: const Color(0xFF16A34A), // Green for plus
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  
  const _QtyButton({required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _EmptyCartState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyCartState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            'https://cdn-icons-png.flaticon.com/512/11329/11329060.png',
            height: 120,
            width: 120,
            errorBuilder: (context, error, stackTrace) => 
               Icon(Icons.shopping_cart_outlined, size: 100, color: Colors.grey[300]),
          ),
          const SizedBox(height: 24),
          const Text('Carrito Vacío', 
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          Text('Explora el inventario y realiza tu venta', 
            style: TextStyle(color: Colors.grey[400], fontSize: 16)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.search),
            label: const Text('BUSCAR PRODUCTOS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 8,
              shadowColor: const Color(0xFF16A34A).withOpacity(0.4),
            ),
          )
        ],
      ),
    );
  }
}

class _ProductSelectionDialog extends StatefulWidget {
  final String apiUrl;
  final int tiendaId;
  final Function(Map<String, dynamic>, int) onProductSelected;

  const _ProductSelectionDialog({
    required this.apiUrl,
    required this.tiendaId,
    required this.onProductSelected,
  });

  @override
  State<_ProductSelectionDialog> createState() => _ProductSelectionDialogState();
}

class _ProductSelectionDialogState extends State<_ProductSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final response = await http.get(
        Uri.parse('${widget.apiUrl}/get_almacen.php?tienda=${widget.tiendaId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _products = data['productos'];
            _filteredProducts = _products;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = data['error'] ?? 'Error desconocido';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Error HTTP: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexión: $e';
        _isLoading = false;
      });
    }
  }

  void _filterProducts(String query) {
    setState(() {
      _filteredProducts = _products.where((p) {
        final name = p['nombre_producto'].toString().toLowerCase();
        final code = p['codigo_barras'].toString().toLowerCase();
        final search = query.toLowerCase();
        return name.contains(search) || code.contains(search);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 40, offset: Offset(0, 20))],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Buscar Producto', 
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: _filterProducts,
                    autofocus: true,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      hintText: 'Nombre o Código...',
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF16A34A)),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                  ),
                ],
              ),
            ),
            
            // List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)))
                  : _filteredProducts.isEmpty
                      ? Center(child: Text('No hay productos', style: TextStyle(color: Colors.grey[400], fontSize: 16)))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          itemCount: _filteredProducts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            final stock = int.tryParse(product['stock'].toString()) ?? 0;
                            final hasStock = stock > 0;
                            
                            return Opacity(
                              opacity: hasStock ? 1.0 : 0.5,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: hasStock ? () {
                                    widget.onProductSelected(product, stock);
                                    Navigator.pop(context);
                                  } : null,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 50, height: 50,
                                          decoration: BoxDecoration(
                                            color: hasStock ? const Color(0xFFDCFCE7) : Colors.grey[200],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Center(
                                            child: Text('📦', style: TextStyle(fontSize: 24, color: hasStock ? null : Colors.grey)),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(product['nombre_producto'], 
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937))),
                                              const SizedBox(height: 4),
                                              Text('Stock: $stock', 
                                                style: TextStyle(color: hasStock ? const Color(0xFF16A34A) : Colors.red, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                        Text('Bs ${product['precio']}', 
                                           style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF16A34A))),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItem {
  _CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.maxStock,
  });

  final int id;
  final String name;
  final double price;
  int quantity;
  final int maxStock;

  double get subtotal => price * quantity;
}
