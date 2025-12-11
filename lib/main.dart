import 'package:flutter/material.dart';
import 'almacen/almacen_page.dart';
import 'ventas/ventas_page.dart';
import 'reporte/reporte_page.dart';
import 'tiendas/tiendas_page.dart';

void main() {
  runApp(const MyApp());
}

class _MainMenuCard extends StatefulWidget {
  const _MainMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_MainMenuCard> createState() => _MainMenuCardState();
}

class _MainMenuCardState extends State<_MainMenuCard> with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..scale(_isPressed ? 0.97 : 1.0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [
              widget.color.withOpacity(0.95),
              widget.color.withOpacity(0.75),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(_isPressed ? 0.25 : 0.4),
              blurRadius: _isPressed ? 12 : 20,
              offset: Offset(0, _isPressed ? 6 : 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.95),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                color: widget.color,
                size: 28,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.title,
                    style: textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.95),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withOpacity(0.7),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Puerto Evo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          // Paleta principal fucsia/rosado intermedio
          seedColor: const Color(0xFFE91E63),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        fontFamily: 'Roboto',
      ),
      home: const MyHomePage(title: 'Puerto Evo – Ventas'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedStoreIndex = 0;
  int _currentTabIndex = 0;

  final List<String> _stores = [
    'Tienda Puerto Centro',
    'Tienda Puerto Norte',
    'Todas las tiendas',
  ];

  String _getCurrentDate() {
    final now = DateTime.now();
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    final days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    
    final dayName = days[now.weekday - 1];
    final day = now.day;
    final month = months[now.month - 1];
    final year = now.year;
    
    return '$dayName, $day de $month de $year';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Datos ficticios para el ejemplo (base de todo)
    const double totalHoyTienda1 = 1520.75;
    const double totalHoyTienda2 = 980.40;

    // Total global y por tienda según selección
    final double totalHoyGlobal = totalHoyTienda1 + totalHoyTienda2;
    final double totalHoySeleccionado = _selectedStoreIndex == 0
        ? totalHoyTienda1
        : _selectedStoreIndex == 1
            ? totalHoyTienda2
            : totalHoyGlobal;

    // Mejores productos ficticios
    final List<_ProductSale> topProducts = [
      const _ProductSale(
        name: 'Energizante Amazonia 500ml',
        quantity: 46,
        total: 414.00,
      ),
      const _ProductSale(
        name: 'Agua Mineral Río Claro 2L',
        quantity: 32,
        total: 192.00,
      ),
      const _ProductSale(
        name: 'Snack Chipa Clásica',
        quantity: 27,
        total: 135.00,
      ),
    ];

    final List<_InventoryItem> lowStockItems = [
      const _InventoryItem(
        name: 'Energizante Amazonia 500ml',
        stock: 8,
        status: InventoryStatus.low,
      ),
      const _InventoryItem(
        name: 'Gaseosa Puerto Cola 1.5L',
        stock: 5,
        status: InventoryStatus.critical,
      ),
      const _InventoryItem(
        name: 'Agua Mineral Río Claro 2L',
        stock: 12,
        status: InventoryStatus.low,
      ),
    ];

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFCE4EC),
                const Color(0xFFF8BBD0).withOpacity(0.5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            titleSpacing: 20,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Panel de ventas',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.black54,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getCurrentDate(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            centerTitle: false,
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.7),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: colorScheme.primary,
                  ),
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFCE4EC), // rosa muy claro
              Color(0xFFF8BBD0), // rosa suave
              Color(0xFFF48FB1), // rosa más intenso
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_currentTabIndex != 0) ...[
                  _StoreSelector(
                    stores: _stores,
                    selectedIndex: _selectedStoreIndex,
                    onChanged: (index) {
                      setState(() {
                        _selectedStoreIndex = index;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: _buildCurrentTab(
                      colorScheme: colorScheme,
                      totalHoyGlobal: totalHoyGlobal,
                      totalHoySeleccionado: totalHoySeleccionado,
                      topProducts: topProducts,
                      lowStockItems: lowStockItems,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 70,
            child: InkWell(
              onTap: () {
                setState(() {
                  _currentTabIndex = 0;
                });
              },
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _currentTabIndex == 0
                            ? colorScheme.primary.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.dashboard_rounded,
                        color: _currentTabIndex == 0
                            ? colorScheme.primary
                            : Colors.black54,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Inicio',
                      style: TextStyle(
                        color: _currentTabIndex == 0
                            ? colorScheme.primary
                            : Colors.black54,
                        fontSize: 12,
                        fontWeight: _currentTabIndex == 0
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTab({
    required ColorScheme colorScheme,
    required double totalHoyGlobal,
    required double totalHoySeleccionado,
    required List<_ProductSale> topProducts,
    required List<_InventoryItem> lowStockItems,
  }) {
    switch (_currentTabIndex) {
      case 0:
        return _buildMainMenu(
          colorScheme: colorScheme,
          totalHoyGlobal: totalHoyGlobal,
        );
      case 1:
        return AlmacenPage();
      case 2:
        return _buildReportsTab(
          colorScheme: colorScheme,
          totalHoy: totalHoySeleccionado,
          topProducts: topProducts,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMainMenu({
    required ColorScheme colorScheme,
    required double totalHoyGlobal,
  }) {
    final textTheme = Theme.of(context).textTheme;

    // Datos de ventas por tienda
    const double ventasTienda1 = 1520.75;
    const double ventasTienda2 = 980.40;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.7),
                Colors.white.withOpacity(0.4),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.8),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withOpacity(0.2),
                          colorScheme.primary.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.waving_hand_rounded,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¡Bienvenido!',
                          style: textTheme.headlineSmall?.copyWith(
                            color: Colors.black87,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Panel principal de gestión',
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const VentasPage(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A), // Verde
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.add_shopping_cart_rounded),
                            label: const Text(
                              'NUEVA VENTA',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
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
        
        // Sección de ventas por tienda
        Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withOpacity(0.9),
                    colorScheme.primary.withOpacity(0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.store_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              'Ventas de hoy',
              style: textTheme.titleLarge?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Tarjetas de tiendas
        Row(
          children: [
            Expanded(
              child: _StoreSalesCard(
                storeName: 'Puerto Centro',
                sales: ventasTienda1,
                icon: Icons.location_city_rounded,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StoreSalesCard(
                storeName: 'Puerto Norte',
                sales: ventasTienda2,
                icon: Icons.store_mall_directory_rounded,
                color: Colors.purpleAccent,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 28),
        _MainMenuCard(
          icon: Icons.storefront_rounded,
          title: 'Ventas por tienda',
          subtitle: 'Resumen diario y top productos',
          color: colorScheme.primary,
          onTap: () {
            setState(() {
              _currentTabIndex = 2;
            });
          },
        ),
        const SizedBox(height: 18),
        _MainMenuCard(
          icon: Icons.inventory_2_rounded,
          title: 'Almacén',
          subtitle: 'Stock, criticidad y alertas',
          color: Colors.orangeAccent,
          onTap: () {
            setState(() {
              _currentTabIndex = 1;
            });
          },
        ),
        const SizedBox(height: 18),
        _MainMenuCard(
          icon: Icons.bar_chart_rounded,
          title: 'Reportes',
          subtitle: 'Indicadores y comportamiento',
          color: Colors.purpleAccent,
          onTap: () {
            setState(() {
              _currentTabIndex = 2;
            });
          },
        ),
        const SizedBox(height: 18),
        _MainMenuCard(
          icon: Icons.fact_check_rounded,
          title: 'Inventario',
          subtitle: 'Control de existencias',
          color: Colors.teal,
          onTap: () {
            setState(() {
              _currentTabIndex = 1;
            });
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
  Widget _buildReportsTab({
    required ColorScheme colorScheme,
    required double totalHoy,
    required List<_ProductSale> topProducts,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: 'Suma total del día',
          icon: Icons.paid_rounded,
          color: colorScheme.primary,
        ),
        const SizedBox(height: 12),
        _SummaryRow(totalHoy: totalHoy),
        const SizedBox(height: 24),
        const _SectionTitle(
          title: 'Top productos vendidos',
          icon: Icons.leaderboard,
          color: Colors.orangeAccent,
        ),
        const SizedBox(height: 12),
        _TopProductsList(products: topProducts),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _StoreSelector extends StatelessWidget {
  const _StoreSelector({
    required this.stores,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> stores;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < stores.length; i++) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: i == selectedIndex
                        ? colorScheme.primary.withOpacity(0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    child: Text(
                      stores[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            i == selectedIndex ? FontWeight.w600 : FontWeight.w400,
                        color: i == selectedIndex
                            ? colorScheme.primary
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (i != stores.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.totalHoy,
  });

  final double totalHoy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _FuturisticCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total vendido hoy',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bs ${totalHoy.toStringAsFixed(2)}',
                  style: textTheme.headlineSmall?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.arrow_upward,
                            size: 14,
                            color: Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+12% vs ayer',
                            style: textTheme.labelSmall?.copyWith(
                              color: const Color(0xFF16A34A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '32 tickets',
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: const [
              _MiniStatCard(
                label: 'Ticket prom.',
                value: 'Bs 78.50',
              ),
              SizedBox(height: 12),
              _MiniStatCard(
                label: 'Productos hoy',
                value: '94 uds',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FuturisticCard extends StatelessWidget {
  const _FuturisticCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.95),
            Colors.white.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.9),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 8,
            offset: const Offset(-4, -4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return _FuturisticCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopProductsList extends StatelessWidget {
  const _TopProductsList({
    required this.products,
  });

  final List<_ProductSale> products;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        for (int i = 0; i < products.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == products.length - 1 ? 0 : 14),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.95),
                    Colors.white.withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.9),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: i == 0
                        ? Colors.orangeAccent.withOpacity(0.2)
                        : Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: i == 0
                            ? [
                                Colors.orangeAccent.withOpacity(0.3),
                                Colors.orangeAccent.withOpacity(0.15),
                              ]
                            : [
                                Colors.grey.withOpacity(0.2),
                                Colors.grey.withOpacity(0.1),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Text(
                      '#${i + 1}',
                      style: textTheme.titleMedium?.copyWith(
                        color: i == 0 ? Colors.orangeAccent[700] : Colors.black87,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          products[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyLarge?.copyWith(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE91E63).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${products[i].quantity} uds',
                                style: textTheme.labelSmall?.copyWith(
                                  color: const Color(0xFFE91E63),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Bs ${products[i].total.toStringAsFixed(2)}',
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.black26,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StoreSalesCard extends StatefulWidget {
  const _StoreSalesCard({
    required this.storeName,
    required this.sales,
    required this.icon,
    required this.color,
  });

  final String storeName;
  final double sales;
  final IconData icon;
  final Color color;

  @override
  State<_StoreSalesCard> createState() => _StoreSalesCardState();
}

class _StoreSalesCardState extends State<_StoreSalesCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.95),
              Colors.white.withOpacity(0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.9),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(_isPressed ? 0.15 : 0.2),
              blurRadius: _isPressed ? 15 : 20,
              offset: Offset(0, _isPressed ? 8 : 10),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: 8,
              offset: const Offset(-4, -4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.color.withOpacity(_isPressed ? 0.3 : 0.25),
                        widget.color.withOpacity(_isPressed ? 0.2 : 0.15),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.color,
                    size: 24,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.trending_up_rounded,
                        size: 14,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '+8%',
                        style: textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF16A34A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              widget.storeName,
              style: textTheme.bodySmall?.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bs ${widget.sales.toStringAsFixed(2)}',
              style: textTheme.headlineSmall?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 14,
                    color: widget.color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '18 tickets',
                    style: textTheme.labelSmall?.copyWith(
                      color: widget.color,
                      fontWeight: FontWeight.w700,
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

class _ProductSale {
  const _ProductSale({
    required this.name,
    required this.quantity,
    required this.total,
  });

  final String name;
  final int quantity;
  final double total;
}

enum InventoryStatus { ok, low, critical }

class _InventoryItem {
  const _InventoryItem({
    required this.name,
    required this.stock,
    required this.status,
  });

  final String name;
  final int stock;
  final InventoryStatus status;
}
