import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

enum InventoryStatus { ok, low, critical }

class _InventoryItem {
  const _InventoryItem({
    required this.name,
    required this.stock,
    required this.status,
    this.barcode,
    this.precio,
  });

  final String name;
  final int stock;
  final InventoryStatus status;
  final String? barcode;
  final double? precio;
}

class AlmacenPage extends StatefulWidget {
  const AlmacenPage({super.key});

  @override
  State<AlmacenPage> createState() => _AlmacenPageState();
}

class _AlmacenPageState extends State<AlmacenPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<_InventoryItem> _items = [];
  String _searchQuery = '';
  late AnimationController _scanSuccessController;
  bool _isLoading = true;
  
  // URL de tu API (cambia localhost por tu IP si pruebas en dispositivo físico)
  final String apiUrl = 'http://192.168.0.224/puerto_evo';
  
  // Tienda actual (1 = Centro, 2 = Norte)
  int _tiendaActual = 1;

  @override
  void initState() {
    super.initState();
    _scanSuccessController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cargarProductos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scanSuccessController.dispose();
    super.dispose();
  }


  // Cargar productos desde la base de datos
  Future<void> _cargarProductos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final url = '$apiUrl/get_almacen.php?tienda=$_tiendaActual';
      print('🔍 Cargando desde: $url'); // Debug
      
      final response = await http.get(Uri.parse(url));
      
      print('📡 Status Code: ${response.statusCode}'); // Debug
      print('📦 Response: ${response.body}'); // Debug

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          final List<dynamic> productos = data['productos'];
          
          print('✅ Productos cargados: ${productos.length}'); // Debug
          
          setState(() {
            _items = productos.map((p) {
              int stock = int.parse(p['stock'].toString());
              InventoryStatus status;
              
              if (stock <= 5) {
                status = InventoryStatus.critical;
              } else if (stock <= 10) {
                status = InventoryStatus.low;
              } else {
                status = InventoryStatus.ok;
              }
              
              return _InventoryItem(
                name: p['nombre_producto'],
                stock: stock,
                status: status,
                barcode: p['codigo_barras'],
                precio: double.parse(p['precio'].toString()),
              );
            }).toList();
            _isLoading = false;
          });
          
          _showSuccessSnackbar('Cargados ${productos.length} productos de tienda $_tiendaActual');
        } else {
          setState(() {
            _isLoading = false;
          });
          _showErrorSnackbar('Error: ${data['error'] ?? 'Error desconocido'}');
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackbar('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('❌ Error: $e'); // Debug
      _showErrorSnackbar('Error al cargar productos: $e');
    }
  }


  List<_InventoryItem> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    return _items.where((item) {
      return item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (item.barcode?.contains(_searchQuery) ?? false);
    }).toList();
  }

  int get _totalProducts => _items.length;
  int get _lowStockCount => _items.where((item) => item.status == InventoryStatus.low).length;
  int get _criticalStockCount => _items.where((item) => item.status == InventoryStatus.critical).length;

  void _startBarcodeScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ModernScannerScreen(
          onBarcodeDetected: _onBarcodeDetected,
        ),
      ),
    );
  }

  Future<void> _onBarcodeDetected(String code) async {
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
        
        if (data['success']) {
          if (data['exists']) {
            // Producto ya existe
            _showProductFoundDialog(
              data['producto']['nombre_producto'],
              data['stock'].toString(),
              code,
            );
          } else {
            // Producto agregado
            _showSuccessSnackbar('Producto agregado al almacén');
          }
          // Recargar lista
          _cargarProductos();
        } else {
          _showErrorSnackbar(data['error'] ?? 'Error desconocido');
        }
      }
    } catch (e) {
      _showErrorSnackbar('Error: $e');
    }
  }

  void _showProductFoundDialog(String nombre, String stock, String codigo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: const Color(0xFF16A34A)),
            const SizedBox(width: 12),
            const Text('Producto encontrado'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nombre,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text('Stock actual: $stock unidades'),
            Text('Código: $codigo'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector de tienda
        _buildTiendaSelector(),
        const SizedBox(height: 16),
        
        // Estadísticas del almacén
        _buildStatisticsSection(),
        const SizedBox(height: 20),
        
        
        // Botones de acción
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildScanButton(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAddManualButton(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Barra de búsqueda
        _buildSearchBar(),
        const SizedBox(height: 20),
        
        // Título de sección
        const _SectionTitle(
          title: 'Productos en almacén',
          icon: Icons.inventory_2_rounded,
          color: Color(0xFFF50057),
        ),
        const SizedBox(height: 12),
        
        // Lista de productos
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _InventoryList(items: _filteredItems),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTiendaSelector() {
    return Row(
      children: [
        Expanded(
          child: _TiendaButton(
            nombre: 'Puerto Centro',
            icono: Icons.store_rounded,
            color: const Color(0xFFF50057),
            isSelected: _tiendaActual == 1,
            onTap: () {
              setState(() {
                _tiendaActual = 1;
              });
              _cargarProductos();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TiendaButton(
            nombre: 'Puerto Norte',
            icono: Icons.store_mall_directory_rounded,
            color: const Color(0xFF9C27B0),
            isSelected: _tiendaActual == 2,
            onTap: () {
              setState(() {
                _tiendaActual = 2;
              });
              _cargarProductos();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsSection() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.inventory_rounded,
            label: 'Total',
            value: '$_totalProducts',
            color: const Color(0xFFF50057),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.warning_rounded,
            label: 'Bajo',
            value: '$_lowStockCount',
            color: Colors.orangeAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.error_rounded,
            label: 'Crítico',
            value: '$_criticalStockCount',
            color: const Color(0xFFDC2626),
          ),
        ),
      ],
    );
  }

  Widget _buildScanButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF50057),
            const Color(0xFFE91E63),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF50057).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _startBarcodeScanner,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Escanear Código de Barras',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Toca para abrir la cámara',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddManualButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF9C27B0),
            const Color(0xFF7B1FA2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _mostrarFormularioAgregarProducto,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.add_circle_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Agregar\nManual',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarFormularioAgregarProducto() {
    final codigoController = TextEditingController();
    final nombreController = TextEditingController();
    final costoTotalController = TextEditingController();
    final cantidadController = TextEditingController();
    final margenController = TextEditingController(text: '35'); // Margen por defecto 35%
    final precioVentaController = TextEditingController();
    final stockController = TextEditingController();

    // Función para calcular el precio de venta unitario
    void calcularPrecioVenta() {
      final costoTotal = double.tryParse(costoTotalController.text) ?? 0;
      final cantidad = int.tryParse(cantidadController.text) ?? 0;
      final margen = double.tryParse(margenController.text) ?? 0;
      
      if (costoTotal > 0 && cantidad > 0 && margen >= 0) {
        // Calcular costo unitario
        final costoUnitario = costoTotal / cantidad;
        
        // Aplicar margen de ganancia
        final precioVenta = costoUnitario * (1 + (margen / 100));
        
        precioVentaController.text = precioVenta.toStringAsFixed(2);
      } else {
        precioVentaController.text = '';
      }
    }

    // Listeners para recalcular automáticamente
    costoTotalController.addListener(calcularPrecioVenta);
    cantidadController.addListener(calcularPrecioVenta);
    margenController.addListener(calcularPrecioVenta);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                const Color(0xFFFCE4EC),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9C27B0).withOpacity(0.3),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header con icono
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF9C27B0),
                          const Color(0xFFE91E63),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9C27B0).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_shopping_cart_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Título
                  const Text(
                    'Agregar Producto',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9C27B0),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Completa la información del nuevo producto',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  // Campo: Código de Barras
                  _buildModernTextField(
                    controller: codigoController,
                    label: 'Código de Barras',
                    hint: 'Ingresa el código',
                    icon: Icons.qr_code_scanner_rounded,
                    keyboardType: TextInputType.number,
                    color: const Color(0xFF9C27B0),
                  ),
                  const SizedBox(height: 20),
                  
                  // Campo: Nombre del Producto
                  _buildModernTextField(
                    controller: nombreController,
                    label: 'Nombre del Producto',
                    hint: 'Ej: Coca Cola 2L',
                    icon: Icons.inventory_2_rounded,
                    color: const Color(0xFFE91E63),
                  ),
                  const SizedBox(height: 24),
                  
                  // Separador visual
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                const Color(0xFFFF6F00).withOpacity(0.3),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '💰 CÁLCULO DE PRECIO',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFFF6F00),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                const Color(0xFFFF6F00).withOpacity(0.3),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Campo: Costo Total
                  _buildModernTextField(
                    controller: costoTotalController,
                    label: 'Costo Total (Bs)',
                    hint: 'Ej: 2000',
                    icon: Icons.shopping_cart_rounded,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    color: const Color(0xFFFF6F00),
                  ),
                  const SizedBox(height: 20),
                  
                  // Campo: Cantidad de Unidades
                  _buildModernTextField(
                    controller: cantidadController,
                    label: 'Cantidad de Unidades',
                    hint: 'Ej: 500',
                    icon: Icons.inventory_2_rounded,
                    keyboardType: TextInputType.number,
                    color: const Color(0xFF2196F3),
                  ),
                  const SizedBox(height: 20),
                  
                  // Campo: Margen de Ganancia
                  _buildModernTextField(
                    controller: margenController,
                    label: 'Margen de Ganancia (%)',
                    hint: 'Ej: 35',
                    icon: Icons.trending_up_rounded,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    color: const Color(0xFF4CAF50),
                  ),
                  const SizedBox(height: 20),
                  
                  // Campo: Precio de Venta (calculado automáticamente)
                  _buildCalculatedPriceField(precioVentaController),
                  const SizedBox(height: 32),
                  
                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: _buildCancelButton(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _buildAddButton(
                          context,
                          codigoController,
                          nombreController,
                          costoTotalController,
                          precioVentaController,
                          cantidadController,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          hintStyle: TextStyle(
            color: Colors.black.withOpacity(0.3),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }

  Widget _buildCalculatedPriceField(TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFF3E0),
            const Color(0xFFFFE0B2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF6F00).withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6F00).withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        readOnly: true,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Color(0xFFFF6F00),
        ),
        decoration: InputDecoration(
          labelText: 'Precio de Venta Unitario (Calculado)',
          hintText: '0.00',
          labelStyle: const TextStyle(
            color: Color(0xFFFF6F00),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          hintStyle: TextStyle(
            color: const Color(0xFFFF6F00).withOpacity(0.3),
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF6F00),
                  const Color(0xFFFF8F00),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6F00).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.calculate_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          suffixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6F00).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'AUTO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFF6F00),
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }

  Widget _buildCancelButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withOpacity(0.1),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.close_rounded,
                  color: Colors.black.withOpacity(0.6),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Cancelar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildAddButton(
    BuildContext context,
    TextEditingController codigoController,
    TextEditingController nombreController,
    TextEditingController costoTotalController,
    TextEditingController precioVentaController,
    TextEditingController cantidadController,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF9C27B0),
            const Color(0xFFE91E63),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Validar campos
            if (codigoController.text.isEmpty ||
                nombreController.text.isEmpty ||
                costoTotalController.text.isEmpty ||
                precioVentaController.text.isEmpty ||
                cantidadController.text.isEmpty) {
              _showErrorSnackbar('Por favor completa todos los campos');
              return;
            }

            // Agregar producto
            _agregarProductoManual(
              codigoController.text,
              nombreController.text,
              double.tryParse(costoTotalController.text) ?? 0,
              double.tryParse(precioVentaController.text) ?? 0,
              int.tryParse(cantidadController.text) ?? 0,
            );

            Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                SizedBox(width: 10),
                Text(
                  'Agregar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _agregarProductoManual(
    String codigo,
    String nombre,
    double costoTotal,
    double precioVentaUnitario,
    int stock,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/agregar_producto.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'codigo_barras': codigo,
          'nombre_producto': nombre,
          'costo_total': costoTotal,
          'precio_venta_unitario': precioVentaUnitario,
          'stock': stock,
          'tienda': _tiendaActual,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success']) {
          _showSuccessSnackbar('Producto "$nombre" agregado correctamente');
          _cargarProductos();
        } else {
          _showErrorSnackbar(data['error'] ?? 'Error al agregar producto');
        }
      } else {
        _showErrorSnackbar('Error HTTP: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackbar('Error al agregar producto: $e');
    }
  }



  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.9),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Buscar por nombre o código...',
          hintStyle: TextStyle(
            color: Colors.black.withOpacity(0.4),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: const Color(0xFFF50057),
            size: 24,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

// Widget de estadística
class _StatCard extends StatelessWidget {
  const _StatCard({
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.95),
            Colors.white.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.9),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

// Pantalla de escáner moderna
class _ModernScannerScreen extends StatefulWidget {
  const _ModernScannerScreen({
    required this.onBarcodeDetected,
  });

  final Function(String) onBarcodeDetected;

  @override
  State<_ModernScannerScreen> createState() => _ModernScannerScreenState();
}

class _ModernScannerScreenState extends State<_ModernScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        setState(() {
          _isProcessing = true;
        });
        
        widget.onBarcodeDetected(barcode.rawValue!);
        Navigator.of(context).pop();
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Cámara
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
          
          // Overlay con guías
          CustomPaint(
            painter: _ScannerOverlayPainter(),
            child: Container(),
          ),
          
          // AppBar personalizado
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            cameraController.torchEnabled
                                ? Icons.flash_on
                                : Icons.flash_off,
                            color: Colors.white,
                          ),
                          onPressed: () => cameraController.toggleTorch(),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: const [
                      Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Apunta al código de barras',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'El escaneo es automático',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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

// Painter para el overlay del escáner
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5);
    
    final scanArea = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.7,
      height: size.height * 0.35,
    );
    
    // Dibujar overlay oscuro
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(RRect.fromRectAndRadius(scanArea, const Radius.circular(20))),
      ),
      paint,
    );
    
    // Dibujar esquinas
    final cornerPaint = Paint()
      ..color = const Color(0xFFF50057)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    
    final cornerLength = 30.0;
    
    // Esquina superior izquierda
    canvas.drawPath(
      Path()
        ..moveTo(scanArea.left, scanArea.top + cornerLength)
        ..lineTo(scanArea.left, scanArea.top)
        ..lineTo(scanArea.left + cornerLength, scanArea.top),
      cornerPaint,
    );
    
    // Esquina superior derecha
    canvas.drawPath(
      Path()
        ..moveTo(scanArea.right - cornerLength, scanArea.top)
        ..lineTo(scanArea.right, scanArea.top)
        ..lineTo(scanArea.right, scanArea.top + cornerLength),
      cornerPaint,
    );
    
    // Esquina inferior izquierda
    canvas.drawPath(
      Path()
        ..moveTo(scanArea.left, scanArea.bottom - cornerLength)
        ..lineTo(scanArea.left, scanArea.bottom)
        ..lineTo(scanArea.left + cornerLength, scanArea.bottom),
      cornerPaint,
    );
    
    // Esquina inferior derecha
    canvas.drawPath(
      Path()
        ..moveTo(scanArea.right - cornerLength, scanArea.bottom)
        ..lineTo(scanArea.right, scanArea.bottom)
        ..lineTo(scanArea.right, scanArea.bottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.9),
                color.withOpacity(0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 22,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 14),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
        ),
      ],
    );
  }
}

class _InventoryList extends StatelessWidget {
  const _InventoryList({required this.items});

  final List<_InventoryItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              'No se encontraron productos',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return _InventoryItemCard(item: item);
      },
    );
  }
}

class _InventoryItemCard extends StatelessWidget {
  const _InventoryItemCard({required this.item});

  final _InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(item.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Indicador de estado (Barra lateral)
            Container(
              width: 6,
              color: statusColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    // Información del producto
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (item.precio != null)
                             Text(
                              'Bs ${item.precio!.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          if (item.barcode != null) ...[
                             const SizedBox(height: 2),
                             Text(
                              item.barcode!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                                letterSpacing: 0.5,
                              ),
                             ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Stock Grande y Claro
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.stock.toString(),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                          Text(
                            'En stock',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: statusColor.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Color _getStatusColor(InventoryStatus status) {
    switch (status) {
      case InventoryStatus.ok:
        return const Color(0xFF16A34A);
      case InventoryStatus.low:
        return Colors.orangeAccent;
      case InventoryStatus.critical:
        return const Color(0xFFDC2626);
    }
  }

  IconData _getStatusIcon(InventoryStatus status) {
    switch (status) {
      case InventoryStatus.ok:
        return Icons.check_circle_rounded;
      case InventoryStatus.low:
        return Icons.warning_rounded;
      case InventoryStatus.critical:
        return Icons.error_rounded;
    }
  }

  String _getStatusText(InventoryStatus status) {
    switch (status) {
      case InventoryStatus.ok:
        return 'OK';
      case InventoryStatus.low:
        return 'BAJO';
      case InventoryStatus.critical:
        return 'CRÍTICO';
    }
  }
}

// Widget de botón de tienda
class _TiendaButton extends StatelessWidget {
  const _TiendaButton({
    required this.nombre,
    required this.icono,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String nombre;
  final IconData icono;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? [
                    color,
                    color.withOpacity(0.8),
                  ]
                : [
                    Colors.white.withOpacity(0.95),
                    Colors.white.withOpacity(0.85),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.9),
            width: isSelected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? color.withOpacity(0.4) : Colors.black.withOpacity(0.05),
              blurRadius: isSelected ? 20 : 10,
              offset: Offset(0, isSelected ? 10 : 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.3)
                    : color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icono,
                color: isSelected ? Colors.white : color,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              nombre,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            if (isSelected) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'ACTIVA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
