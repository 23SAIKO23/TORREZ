import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VentasPage extends StatefulWidget {
  const VentasPage({super.key});

  @override
  State<VentasPage> createState() => _VentasPageState();
}

class _VentasPageState extends State<VentasPage> {
  final List<_CartItem> _cart = [];
  bool _isLoading = false;
  
  // URL API (Ajustar según necesidad)
  final String apiUrl = 'http://192.168.0.224/puerto_evo';
  int _tiendaActual = 1; // Default: Puerto Centro

  double get _totalVenta => _cart.fold(0, (sum, item) => sum + item.subtotal);

  void _startScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ScannerScreen(onCodeDetected: _onCodeDetected),
      ),
    );
  }

  Future<void> _onCodeDetected(String code) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/buscar_producto.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'codigo_barras': code,
          'tienda': _tiendaActual,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['exists'] == true) {
           final prod = data['producto'];
           final stock = int.tryParse(data['stock'].toString()) ?? 0;
           
           if(stock > 0) {
             _addToCart(prod, stock);
             _showSnack('Producto agregado: ${prod['nombre_producto']}', Colors.green);
           } else {
             _showSnack('Producto sin stock', Colors.red);
           }
        } else {
           _showSnack('Producto no encontrado', Colors.orange);
        }
      } else {
        _showSnack('Error de conexión', Colors.red);
      }
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addToCart(Map<String, dynamic> product, int currentStock) {
    setState(() {
      final existingIndex = _cart.indexWhere((item) => item.id == int.parse(product['id_producto'].toString()));
      
      if (existingIndex >= 0) {
        // Increment
        if (_cart[existingIndex].quantity < currentStock) {
          _cart[existingIndex].quantity++;
        } else {
          _showSnack('No hay más stock disponible', Colors.orange);
        }
      } else {
        // Add new
        _cart.add(_CartItem(
          id: int.parse(product['id_producto'].toString()),
          name: product['nombre_producto'],
          price: double.parse(product['precio_venta_unitario'].toString()), // Asegurar nombre campo
          quantity: 1,
          maxStock: currentStock,
        ));
      }
    });
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

       // Debug
      print('Response: ${response.body}');

      if (response.statusCode == 200) {
         final result = json.decode(response.body);
         if (result['success'] == true) {
           showDialog(
             context: context,
             builder: (_) => AlertDialog(
               title: const Text('¡Venta Exitosa!'),
               content: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   const Icon(Icons.check_circle, color: Colors.green, size: 64),
                   const SizedBox(height: 16),
                   Text('Ticket #${result['ticket']}'),
                   Text('Total: Bs ${_totalVenta.toStringAsFixed(2)}'),
                 ],
               ),
               actions: [
                 TextButton(
                   onPressed: () {
                     Navigator.pop(context); // Close dialog
                     Navigator.pop(context); // Close POS (return to menu)
                   },
                   child: const Text('Aceptar'),
                 )
               ],
             ),
           );
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

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Fondo muy claro
      body: Column(
        children: [
          // Header Moderno
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              left: 24,
              right: 24,
              bottom: 30,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF16A34A),
                  const Color(0xFF16A34A).withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF16A34A).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Nueva Venta',
                      style: TextStyle(
                        fontFamily: 'Roboto', // O la fuente que uses
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF16A34A), size: 28),
                        onPressed: _startScanner,
                        tooltip: 'Escanear',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Resumen rápido en el header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           'Items',
                           style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500),
                         ),
                         Text(
                           '${_cart.length}',
                           style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                         ),
                       ],
                     ),
                     Container(
                       height: 40, 
                       width: 1, 
                       color: Colors.white.withOpacity(0.2)
                     ),
                     Column(
                       crossAxisAlignment: CrossAxisAlignment.end,
                       children: [
                         Text(
                           'Total Actual',
                           style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500),
                         ),
                         Text(
                           'Bs ${_totalVenta.toStringAsFixed(2)}',
                           style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                         ),
                       ],
                     ),
                  ],
                ),
              ],
            ),
          ),

          // Lista de Items
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 20, spreadRadius: 5),
                            ],
                          ),
                          child: Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.grey[300]),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Tu carrito está vacío',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Escanea un producto para comenzar',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _startScanner,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('ESCANEAR AHORA'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 100),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Dismissible(
                            key: Key(item.id.toString()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: const Color(0xFFEF4444),
                              child: const Icon(Icons.delete_outline, color: Colors.white),
                            ),
                            onDismissed: (_) => _removeFromCart(index),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Icono / Imagen del producto
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Center(
                                      child: Text('🎁', style: TextStyle(fontSize: 28)),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Bs ${item.price.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: const Color(0xFF16A34A),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Controles Cantidad
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                        _QuantityButton(
                                          icon: Icons.remove,
                                          onTap: () {
                                            setState(() {
                                              if (item.quantity > 1) {
                                                item.quantity--;
                                              } else {
                                                _removeFromCart(index);
                                              }
                                            });
                                          },
                                        ),
                                        SizedBox(
                                          width: 32,
                                          child: Text(
                                            '${item.quantity}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        _QuantityButton(
                                          icon: Icons.add,
                                          onTap: () {
                                            setState(() {
                                              if (item.quantity < item.maxStock) {
                                                item.quantity++;
                                              } else {
                                                _showSnack('Max stock alcanzado', Colors.orange);
                                              }
                                            });
                                          },
                                        ),
                                      ],
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
      bottomSheet: _cart.isEmpty 
          ? null 
          : Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 30,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total a Pagar',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Bs ${_totalVenta.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _processSale,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          elevation: 10,
                          shadowColor: const Color(0xFF16A34A).withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    'CONFIRMAR VENTA',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Icon(Icons.arrow_forward_rounded),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, size: 16, color: Colors.black54),
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

class _ScannerScreen extends StatefulWidget {
  const _ScannerScreen({required this.onCodeDetected});
  final Function(String) onCodeDetected;

  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _hasDetected = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear Código'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          if (_hasDetected) return;
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
             if (barcode.rawValue != null) {
               setState(() => _hasDetected = true);
               widget.onCodeDetected(barcode.rawValue!);
               Navigator.pop(context);
               break;
             }
          }
        },
      ),
    );
  }
}
