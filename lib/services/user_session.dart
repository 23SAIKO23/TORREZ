/// Singleton service to hold the current user's session data.
/// This allows all pages to access the logged-in user's store assignment.
class UserSession {
  // Private constructor
  UserSession._();
  
  // Singleton instance
  static final UserSession _instance = UserSession._();
  static UserSession get instance => _instance;
  
  // User data
  String _tienda = 'todas las tiendas';
  String _nombre = '';
  String _rol = 'USUARIO';
  int _userId = 0;
  
  // Getters
  String get tienda => _tienda;
  String get nombre => _nombre;
  String get rol => _rol;
  int get userId => _userId;
  
  /// Returns true if user can only see one store (primera or segunda)
  bool get isSingleStore => _tienda == 'primera' || _tienda == 'segunda';
  
  /// Returns true if user can see all stores
  bool get isAllStores => _tienda == 'todas las tiendas';
  
  /// Converts tienda name to numeric ID for API calls
  /// primera = 1, segunda = 2, todas = null (no filter)
  int? get tiendaId {
    if (_tienda == 'primera') return 1;
    if (_tienda == 'segunda') return 2;
    return null; // todas las tiendas - no filter needed
  }
  
  /// Initialize session with user data from login/device approval
  void setUserData({
    required String tienda,
    required String nombre,
    required String rol,
    required int userId,
  }) {
    _tienda = _normalizeStore(tienda);
    _nombre = nombre;
    _rol = rol;
    _userId = userId;
  }
  
  /// Normalize store value for compatibility with old numeric values
  String _normalizeStore(String value) {
    if (value == '1') return 'primera';
    if (value == '2') return 'segunda';
    if (['primera', 'segunda', 'todas las tiendas'].contains(value)) {
      return value;
    }
    return 'todas las tiendas';
  }
  
  /// Clear session data (for logout)
  void clear() {
    _tienda = 'todas las tiendas';
    _nombre = '';
    _rol = 'USUARIO';
    _userId = 0;
  }
}
