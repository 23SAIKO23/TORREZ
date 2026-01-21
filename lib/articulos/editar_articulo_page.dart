import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class EditarArticuloPage extends StatefulWidget {
  const EditarArticuloPage({
    super.key,
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.costoTotal,
    required this.precioVenta,
    required this.stock,
    required this.tienda,
    this.imagenUrl,
  });

  final int id;
  final String codigo;
  final String nombre;
  final double costoTotal;
  final double precioVenta;
  final int stock;
  final int tienda;
  final String? imagenUrl;

  @override
  State<EditarArticuloPage> createState() => _EditarArticuloPageState();
}

class _EditarArticuloPageState extends State<EditarArticuloPage> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _codigoController;
  late TextEditingController _nombreController;
  late TextEditingController _costoTotalController;
  late TextEditingController _precioVentaController;
  late TextEditingController _stockController;
  
  late int _tienda;
  String? _newImagePath;
  bool _isLoading = false;

  final String _apiUrl = 'http://192.168.0.29/puerto_evo';

  @override
  void initState() {
    super.initState();
    _codigoController = TextEditingController(text: widget.codigo);
    _nombreController = TextEditingController(text: widget.nombre);
    _costoTotalController = TextEditingController(text: widget.costoTotal.toStringAsFixed(2));
    _precioVentaController = TextEditingController(text: widget.precioVenta.toStringAsFixed(2));
    _stockController = TextEditingController(text: widget.stock.toString());
    _tienda = widget.tienda;
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _nombreController.dispose();
    _costoTotalController.dispose();
    _precioVentaController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.single.path;
    if (path == null) return;
    setState(() => _newImagePath = path);
  }

  void _clearImage() {
    setState(() => _newImagePath = null);
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final codigoTrim = _codigoController.text.trim();
    final nombreTrim = _nombreController.text.trim();
    final stockInt = int.tryParse(_stockController.text.trim()) ?? 0;
    final costo = double.tryParse(_costoTotalController.text.trim().replaceAll(',', '.')) ?? 0;
    final precio = double.tryParse(_precioVentaController.text.trim().replaceAll(',', '.')) ?? 0;

    if (codigoTrim.isEmpty || nombreTrim.isEmpty || stockInt < 0) {
      _showSnackBar('Completa todos los campos correctamente.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse('$_apiUrl/editar_producto.php');
      final req = http.MultipartRequest('POST', uri);
      
      req.fields['id_producto'] = widget.id.toString();
      req.fields['codigo_barras'] = codigoTrim;
      req.fields['nombre_producto'] = nombreTrim;
      req.fields['costo_total'] = costo.toStringAsFixed(2);
      req.fields['precio_venta_unitario'] = precio.toStringAsFixed(2);
      req.fields['stock'] = stockInt.toString();
      req.fields['tienda'] = _tienda.toString();

      if (_newImagePath != null && _newImagePath!.trim().isNotEmpty) {
        final file = File(_newImagePath!);
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
        if (!mounted) return;
        Navigator.of(context).pop(true); // Return true to indicate success
        return;
      }

      final err = (data is Map ? data['error'] : null) ?? 'Error desconocido';
      throw Exception(err.toString());
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error al actualizar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: isError ? const Color(0xFFDC2626) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14B8A6),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Editar Artículo',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _codigoController,
                label: 'Código de barras',
                hint: 'Ej: 7758...',
                icon: Icons.qr_code_2_rounded,
                validator: (v) => v?.trim().isEmpty ?? true ? 'Requerido' : null,
              ),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _nombreController,
                label: 'Nombre del producto',
                hint: 'Ej: Agua 2L',
                icon: Icons.shopping_bag_rounded,
                validator: (v) => v?.trim().isEmpty ?? true ? 'Requerido' : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _costoTotalController,
                      label: 'Costo total',
                      hint: '0.00',
                      icon: Icons.payments_rounded,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        final val = double.tryParse(v?.trim().replaceAll(',', '.') ?? '');
                        return val == null || val < 0 ? 'Inválido' : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                      controller: _precioVentaController,
                      label: 'Precio venta',
                      hint: '0.00',
                      icon: Icons.price_check_rounded,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        final val = double.tryParse(v?.trim().replaceAll(',', '.') ?? '');
                        return val == null || val < 0 ? 'Inválido' : null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _stockController,
                      label: 'Stock',
                      hint: '0',
                      icon: Icons.inventory_2_rounded,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final val = int.tryParse(v?.trim() ?? '');
                        return val == null || val < 0 ? 'Inválido' : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTiendaPicker(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildImagePicker(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _saveChanges,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _isLoading ? 'Guardando...' : 'Guardar Cambios',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF14B8A6), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14B8A6).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
            ),
            child: const Icon(Icons.edit_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${widget.id}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.85),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontWeight: FontWeight.w700),
        validator: validator,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  Widget _buildTiendaPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _tienda,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 1, child: Text('Puerto Centro')),
            DropdownMenuItem(value: 2, child: Text('Puerto Norte')),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _tienda = v);
          },
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black.withOpacity(0.05),
                ),
                child: const Icon(Icons.image_rounded, color: Colors.black54),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _newImagePath == null ? 'Imagen (opcional)' : _newImagePath!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.upload_rounded),
                  label: const Text('Cambiar imagen'),
                ),
              ),
              if (_newImagePath != null) ...[
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Quitar',
                  onPressed: _clearImage,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ],
          ),
          if (widget.imagenUrl != null && _newImagePath == null) ...[
            const SizedBox(height: 10),
            Text(
              'Imagen actual: ${widget.imagenUrl}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withOpacity(0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
