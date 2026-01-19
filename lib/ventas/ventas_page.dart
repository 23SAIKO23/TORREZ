import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';

class VentasPage extends StatefulWidget {
  final String nombreTienda;
  final int tiendaId;
  
  const VentasPage({
    super.key,
    required this.nombreTienda,
    required this.tiendaId,
  });

  @override
  State<VentasPage> createState() => _VentasPageState();
}

class _VentasPageState extends State<VentasPage> with SingleTickerProviderStateMixin {
  final List<_CartItem> _cart = [];
  bool _isLoading = false;
  
  // URL API 
  final String apiUrl = 'http://192.168.0.29/puerto_evo';
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
        'tienda_id': widget.tiendaId,
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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFBE185D), Color(0xFFEC4899)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- MODERN HEADER ---
              Container(
                margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: const Text(
                            'VENTA ACTIVA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [const Color(0xFFE11D48), const Color(0xFFBE185D)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFFE11D48).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6)),
                            ],
                          ),
                          child: const Icon(Icons.store_rounded, color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trabajando en',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.nombreTienda,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),


              const SizedBox(height: 24),

              // --- MODERN TOTAL DISPLAY ---
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.paid_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'TOTAL VENTA',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Bs',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _totalVenta.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.0,
                              letterSpacing: -2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- MODERN PRODUCT LIST ---
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF831843),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFBE185D).withOpacity(0.4), blurRadius: 30, offset: const Offset(0, -10)),
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
                            // Modern Floating Action Button
                            Positioned(
                              bottom: 24,
                              right: 24,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFE11D48), Color(0xFFBE185D)],
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(color: const Color(0xFFE11D48).withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10)),
                                  ],
                                ),
                                child: FloatingActionButton.extended(
                                  onPressed: () => _showManualSelectionDialog(context),
                                  label: const Text('AGREGAR', style: TextStyle(fontWeight: FontWeight.w700)),
                                  icon: const Icon(Icons.add_rounded, size: 24),
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                ),
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
      // --- MODERN BOTTOM SHEET FOR CHECKOUT ---
      bottomSheet: _cart.isEmpty
          ? null
          : Container(
              decoration: BoxDecoration(
                color: const Color(0xFF831843),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFBE185D).withOpacity(0.4), blurRadius: 30, offset: const Offset(0, -10)),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: SafeArea(
                
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL A PAGAR',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Bs ${_totalVenta.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 200,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE11D48), Color(0xFFBE185D)],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFFE11D48).withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10)),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _processSale,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('FINALIZAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                      SizedBox(width: 8),
                                      Icon(Icons.check_rounded, size: 20)
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
          tiendaId: widget.tiendaId,
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
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(60),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: Colors.white,
              size: 60,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Text(
              'CARRITO VACÍO',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Agrega productos para comenzar',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 40),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE11D48), Color(0xFFBE185D)],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(color: const Color(0xFFE11D48).withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_rounded, size: 24),
              label: const Text('AGREGAR PRODUCTOS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
            ),
          ),
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
        Uri.parse('${widget.apiUrl}/get_inventario.php?tienda=${widget.tiendaId}'),
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
                            final price = double.tryParse(product['precio'].toString()) ?? 0.0;
                            final imageUrl = product['imagen_url'];
                            final hasStock = stock > 0;
                            
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: hasStock ? () {
                                  widget.onProductSelected(product, stock);
                                  Navigator.pop(context);
                                } : null,
                                borderRadius: BorderRadius.circular(20),
                                child: Opacity(
                                  opacity: hasStock ? 1.0 : 0.6,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(color: Colors.grey.withOpacity(0.15)),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.04),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        )
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        // Image Section
                                        Container(
                                          width: 60, height: 60,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: imageUrl != null && imageUrl.isNotEmpty
                                                ? Image.network(
                                                    imageUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (ctx, err, stack) => const Icon(Icons.image_not_supported_rounded, color: Colors.grey),
                                                  )
                                                : const Icon(Icons.image_not_supported_rounded, color: Colors.grey),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // Info Section
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(product['nombre_producto'] ?? 'Sin nombre', 
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937))),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Text('Stock: $stock', 
                                                    style: TextStyle(color: hasStock ? Colors.grey[600] : Colors.red, fontWeight: FontWeight.w600, fontSize: 13)),
                                                  const SizedBox(width: 10),
                                                  if (!hasStock)
                                                    const Text('AGOTADO', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 10)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Price Section
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF16A34A).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            'Bs ${price.toStringAsFixed(2)}', 
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF16A34A)),
                                          ),
                                        ),
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
