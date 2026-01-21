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
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
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
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 56),
                  ),
                  const SizedBox(height: 24),
                  const Text('¡Venta Exitosa!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('Ticket #$ticket', style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 24),
                  Text('Bs ${total.toStringAsFixed(2)}', 
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(context); // Close page
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F2937),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('CERRAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
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
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nueva Venta',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              widget.nombreTienda,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                SizedBox(width: 6),
                Text(
                  'Activa',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              // Total Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF3B82F6), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total de la venta',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: Text(
                              'Bs ${_totalVenta.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${_cart.length} items',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              // Products List
              Expanded(
                child: _cart.isEmpty
                    ? _EmptyCartState(
                        onAdd: () => _showManualSelectionDialog(context),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _cart.length,
                        itemBuilder: (context, index) {
                          return _CartItemCard(
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
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _cart.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showManualSelectionDialog(context),
              backgroundColor: const Color(0xFF3B82F6),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Agregar más', style: TextStyle(fontWeight: FontWeight.w800)),
              elevation: 4,
            )
          : null,
      bottomNavigationBar: _cart.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _processSale,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 24),
                              const SizedBox(width: 12),
                              Text(
                                'Finalizar Venta - Bs ${_totalVenta.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                              ),
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

class _CartItemCard extends StatelessWidget {
  final _CartItem item;
  final VoidCallback onAdd, onRemove, onDelete;

  const _CartItemCard({
    required this.item,
    required this.onAdd,
    required this.onRemove,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF3B82F6), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Bs ${item.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '× ${item.quantity}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '= Bs ${item.subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QuantityButton(
                    icon: Icons.remove_rounded,
                    onTap: onRemove,
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 32),
                    alignment: Alignment.center,
                    child: Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  _QuantityButton(
                    icon: Icons.add_rounded,
                    onTap: onAdd,
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

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QuantityButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
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
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              color: Color(0xFF3B82F6),
              size: 56,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Carrito vacío',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega productos para comenzar la venta',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 22),
            label: const Text(
              'Agregar Productos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
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
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 40, offset: Offset(0, 20))
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.search_rounded, color: Color(0xFF3B82F6), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Buscar Producto',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: _filterProducts,
                    autofocus: true,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Nombre o código de barras...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w600),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
            
            // List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                  : _filteredProducts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'No se encontraron productos',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: _filteredProducts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                                borderRadius: BorderRadius.circular(16),
                                child: Opacity(
                                  opacity: hasStock ? 1.0 : 0.5,
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: hasStock 
                                            ? Colors.transparent 
                                            : const Color(0xFFEF4444).withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Image
                                        Container(
                                          width: 64,
                                          height: 64,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: imageUrl != null && imageUrl.isNotEmpty
                                                ? Image.network(
                                                    imageUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (ctx, err, stack) => 
                                                        const Icon(Icons.image_not_supported_rounded, color: Color(0xFF94A3B8)),
                                                  )
                                                : const Icon(Icons.inventory_2_rounded, color: Color(0xFF94A3B8), size: 32),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        // Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product['nombre_producto'] ?? 'Sin nombre',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                  color: Color(0xFF1F2937),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: hasStock 
                                                          ? const Color(0xFF10B981).withOpacity(0.1)
                                                          : const Color(0xFFEF4444).withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      hasStock ? 'Stock: $stock' : 'AGOTADO',
                                                      style: TextStyle(
                                                        color: hasStock ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                                        fontWeight: FontWeight.w800,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Price
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Bs ${price.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                              color: Color(0xFF3B82F6),
                                            ),
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
